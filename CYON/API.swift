//
//  API.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import Alamofire
import FeedKit
import Foundation

class API {

    static let shared = API()

    // Digital Podcast directory
    static let digitalPodcastAppID = "42753bb3eb6a7fcd4cb622f484acc0da"
    static let digitalPodcastBaseURL = "http://api.digitalpodcast.com/v2r"

    // private
    private let dataCache = NSCache<AnyObject, AnyObject>()
    private var useITunesDirectory = true

    // MARK: - Public

    func clearCache() {
        dataCache.removeAllObjects()
    }

    func getEpisodes(podcast: Podcast, completion: @escaping ([Episode]) -> Void) {
        guard podcast.feedURL.isEmpty == false,
              let feedURL = URL(string: podcast.feedURL) else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        // get the episodes from the cache
        if let cached = dataCache.object(forKey: podcast.feedURL as AnyObject) as? RSSFeedChannel {
            let episodes = parseEpisodes(channel: cached, podcast: podcast)
            DispatchQueue.main.async { completion(episodes) }
            return
        }

        Task {
            do {
                let feed = try await RSSFeed(url: feedURL)
                guard let channel = feed.channel else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                self.dataCache.setObject(channel as AnyObject, forKey: podcast.feedURL as AnyObject)
                let episodes = self.parseEpisodes(channel: channel, podcast: podcast)
                DispatchQueue.main.async { completion(episodes) }
            } catch {
                NSLog("Error parsing rss feed. (\(error.localizedDescription))")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    func searchPodcasts(searchText: String, completion: @escaping ([Podcast]) -> Void) {
        if useITunesDirectory {
            return searchITunes(searchText: searchText, completion: completion)
        } else {
            return searchDigitalPodcast(searchText: searchText, completion: completion)
        }
    }

    // MARK: - Private

    private func parseEpisodes(channel: RSSFeedChannel, podcast: Podcast) -> [Episode] {
        guard let items = channel.items else {
            return []
        }
        var episodes = [Episode]()
        for item in items {
            var episode = Episode(feed: item)
            if episode.artwork == nil {
                episode.artwork = podcast.artwork
            }
            episodes.append(episode)
        }
        return episodes
    }

    private func searchDigitalPodcast(searchText: String, completion: @escaping ([Podcast]) -> Void) {
        guard let searchString = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "\(API.digitalPodcastBaseURL)/search/?appid=\(API.digitalPodcastAppID)&format=rss&result=50&keywords=\(searchString)") else {
            NSLog("Error creating podcast search url.")
            return
        }

        Task {
            do {
                let feed = try await RSSFeed(url: searchURL)
                var podcasts = [Podcast]()
                if let items = feed.channel?.items {
                    for item in items {
                        if let podcast = Podcast(item: item) {
                            podcasts.append(podcast)
                        }
                    }
                }
                DispatchQueue.main.async { completion(podcasts) }
            } catch {
                NSLog("Error parsing rss feed. (\(error.localizedDescription))")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    private func searchITunes(searchText: String, completion: @escaping ([Podcast]) -> Void) {
        let searchURL = "https://itunes.apple.com/search"

        AF.request(searchURL, method: .get, parameters: ["term": searchText], encoding: URLEncoding.queryString)
            .responseData { response in
                var podcasts = [Podcast]()
                if let data = response.data,
                   let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultCount = result["resultCount"] as? Int,
                   resultCount > 0,
                   let results = result["results"] as? [[String: Any]] {
                    for item in results {
                        if let kind = item["kind"] as? String,
                           kind.lowercased() == "podcast" {
                            podcasts.append(Podcast(json: item))
                        }
                    }
                }
                DispatchQueue.main.async { completion(podcasts) }
            }
    }
}
