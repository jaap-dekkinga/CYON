//
//  DownloadCache.swift
//  Podcast
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 11/12/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import Alamofire
import Foundation

class DownloadCache {

	// static
	static var shared = DownloadCache()

	let maxCachedItems = 5
	var downloads = [Download]()

	// private
	private let downloadFolderURL: URL
	private let downloadIndexURL: URL

	// MARK: -

	init() {
		// create the download cache urls
		downloadFolderURL = AppDelegate.documentsURL.appendingPathComponent("Downloads/")
		downloadIndexURL = AppDelegate.documentsURL.appendingPathComponent("Downloads.plist")
		// load the download index
		loadDownloadIndex()
	}

	// MARK: -

	var cachedItemCount: Int {
		var count = 0
		for download in downloads {
			if (download.isUserDownload == false) {
				count += 1
			}
		}
		return count
	}

	var userDownloads: [PlayerItem] {
		var userDownloads = [PlayerItem]()
		for download in downloads {
			if download.isUserDownload {
				userDownloads.append(download.playerItem)
			}
		}
		return userDownloads
	}

	// MARK: -

	func cachedFile(for playerItem: PlayerItem, completion: @escaping (URL?) -> Void) {

		// check if items should be removed from the cache first
		var cachedItemCount = self.cachedItemCount
		var currentIndex = (downloads.count - 1)
		while ((cachedItemCount > (maxCachedItems - 1)) && (currentIndex >= 0)) {
			let download = downloads[currentIndex]
			if (download.isUserDownload == false) {
				// remove a cache item
				removeDownload(index: currentIndex)
				cachedItemCount -= 1
			}
			currentIndex -= 1
		}

		// download and return the player item
		download(playerItem: playerItem, userDownloaded: false, tryAWS: true, progress: nil, completion: {
			(download, error) in
			DispatchQueue.main.async {
				var cacheFileURL: URL?
				if let cacheFileName = download?.cacheFileName {
					cacheFileURL = self.downloadFolderURL.appendingPathComponent(cacheFileName)
				}
				completion(cacheFileURL)
			}
		})
	}

	func download(playerItem: PlayerItem, progress progressHandler: ((Double) -> Void)?, completion: @escaping (PlayerItem, Error?) -> Void) {

		// check if a cached file already exists
		if let downloadIndex = downloadIndex(for: playerItem) {
			var download = downloads[downloadIndex]
			if (download.isUserDownload == false) {
				// convert the download to a user download
				download.isUserDownload = true
				downloads.remove(at: downloadIndex)
				downloads.insert(download, at: 0)
				_ = saveDownloadIndex()
			}
		}

		// download and return the player item
		download(playerItem: playerItem, userDownloaded: true, tryAWS: true, progress: progressHandler, completion: {
			(download, error) in
			DispatchQueue.main.async {
				completion(playerItem, error)
			}
		})
	}

	func isUserDownloaded(playerItem: PlayerItem) -> Bool {
		if let downloadIndex = downloadIndex(for: playerItem) {
			return downloads[downloadIndex].isUserDownload
		}
		return false
	}

	func removeDownload(for playerItem: PlayerItem) {
		// get the download index
		guard let downloadIndex = downloadIndex(for: playerItem) else {
			return
		}

		// remove the download
		removeDownload(index: downloadIndex)
		_ = saveDownloadIndex()
	}

	// MARK: - Private

	private func download(playerItem: PlayerItem, userDownloaded: Bool, tryAWS: Bool, progress progressHandler: ((Double) -> Void)?, completion: @escaping (Download?, Error?) -> Void) {

    // safety check
    if let downloadIndex = downloadIndex(for: playerItem) {
        let download = downloads[downloadIndex]
        completion(download, nil)
        return
    }

    let awsDownloadAttempt: Bool
    let downloadURL: URL

    // check for an aws feed
    if tryAWS, let awsFeed = AWSFeed.feed(for: playerItem.podcast),
       let awsURL = awsFeed.url(for: playerItem.episode) {
        awsDownloadAttempt = true
        downloadURL = awsURL
    } else {
        guard let episodeURL = URL(string: playerItem.episode.url ?? "") else {
            DispatchQueue.main.async {
                let error = NSError(domain: "Podcast", code: 100, userInfo: nil)
                completion(nil, error)
            }
            return
        }
        downloadURL = episodeURL
        awsDownloadAttempt = false
    }

    // build a download destination
    let destination: DownloadRequest.Destination = { _, _ in
        let fileName = "\(UUID().uuidString)"
        let fileURL = self.downloadFolderURL.appendingPathComponent(fileName)
        return (fileURL, [.createIntermediateDirectories, .removePreviousFile])
    }

    // start the download
    AF.download(downloadURL, to: destination)
        .downloadProgress { progress in
            DispatchQueue.main.async {
                progressHandler?(progress.fractionCompleted)
            }
        }
        .response { response in
            var download: Download?
            var error: Error?

            switch response.result {
            case .success(let fileURL):
                if let fileURL,
                   let statusCode = response.response?.statusCode,
                   (200 ..< 300).contains(statusCode) {
                    // rename the file to include the original extension
                    let ext = response.response?.url?.pathExtension ?? ""
                    let fileName = ext.isEmpty ? fileURL.lastPathComponent : "\(fileURL.deletingPathExtension().lastPathComponent).\(ext)"
                    let destURL = self.downloadFolderURL.appendingPathComponent(fileName)
                    _ = try? FileManager.default.moveItem(at: fileURL, to: destURL)
                    download = Download(cacheFileName: fileName, isUserDownload: userDownloaded, playerItem: playerItem)
                    self.downloads.insert(download!, at: 0)
                    _ = self.saveDownloadIndex()
                } else {
                    fallthrough
                }
            case .failure:
                if awsDownloadAttempt {
                    DispatchQueue.main.async {
                        self.download(playerItem: playerItem, userDownloaded: userDownloaded, tryAWS: false, progress: progressHandler, completion: completion)
                    }
                    return
                } else {
                    error = NSError(domain: "Podcast", code: 101, userInfo: nil)
                }
            }

            completion(download, error)
        }
	}

	private func downloadIndex(for playerItem: PlayerItem) -> Int? {
		for index in 0 ..< downloads.count {
			let download = downloads[index]
			if (download.playerItem == playerItem) {
				return index
			}
		}
		return nil
	}

	private func removeDownload(index: Int) {
		// remove the cache file
		let download = downloads[index]
		do {
			let cacheFileURL = downloadFolderURL.appendingPathComponent(download.cacheFileName)
			try FileManager.default.removeItem(at: cacheFileURL)
		} catch {
			NSLog("Error removing cache file. (\(error.localizedDescription))")
		}

		// update the downloads index
		downloads.remove(at: index)
	}

	// MARK: -

	private func loadDownloadIndex() {
		if let data = try? Data(contentsOf: downloadIndexURL),
		   let savedDownloads = try? PropertyListDecoder().decode([Download].self, from: data) {
			downloads = savedDownloads
		}
	}

	private func saveDownloadIndex() -> Bool {
		do {
			let data = try PropertyListEncoder().encode(downloads)
			try data.write(to: downloadIndexURL)
		} catch {
			NSLog("Error writing downloads index. (\(error.localizedDescription))")
			return false
		}
		return true
	}

}
