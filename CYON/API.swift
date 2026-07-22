//
//  API.swift
//  CYON
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import Alamofire
import FeedKit
import Foundation

/// Podcast metadata and episode feed access.
///
/// Public surface:
/// - `searchPodcasts(searchText:completion:)` — iTunes Search API
/// - `getEpisodes(podcast:completion:)` — RSS feed → `[Episode]` (cached per feed URL)
/// - `clearCache()` — drop the feed cache (call on memory warnings)
///
/// Both fetch methods deliver `completion` on the main queue and return an empty
/// array on any failure (network, parse, missing data). Callers never need to
/// handle errors — they get "no results" instead.
final class API {

	// MARK: - Singleton

	static let shared = API()
	private init() {}

	// MARK: - Cache

	func clearCache() {
		channelCache.removeAllObjects()
	}

	private let channelCache = NSCache<NSString, ChannelBox>()

	// MARK: - Search

	/// Search Apple's podcast directory.
	///
	/// - Note: `media=podcast` is required. Without it iTunes defaults to
	///   `media=all` and returns music / movies / apps, none of which have
	///   `kind == "podcast"` — the filter below would then reject everything.
	func searchPodcasts(searchText: String, completion: @escaping ([Podcast]) -> Void) {
		let parameters: [String: String] = [
			"term": searchText,
			"media": "podcast",
		]

		AF.request(
			Endpoints.iTunesSearch,
			method: .get,
			parameters: parameters,
			encoding: URLEncoding.queryString
		)
		.responseData { response in
			let podcasts = Self.parseSearchResponse(response.data)
			DispatchQueue.main.async { completion(podcasts) }
		}
	}

	// MARK: - Episodes

	func getEpisodes(podcast: Podcast, completion: @escaping ([Episode]) -> Void) {
		guard let feedURL = URL(string: podcast.feedURL), podcast.feedURL.isEmpty == false else {
			deliverOnMain([Episode](), to: completion)
			return
		}

		if let cached = channelCache.object(forKey: podcast.feedURL as NSString) {
			let episodes = parseEpisodes(channel: cached.channel, podcast: podcast)
			deliverOnMain(episodes, to: completion)
			return
		}

		Task {
			let episodes = await fetchAndCacheEpisodes(feedURL: feedURL, podcast: podcast)
			deliverOnMain(episodes, to: completion)
		}
	}

	private func fetchAndCacheEpisodes(feedURL: URL, podcast: Podcast) async -> [Episode] {
		do {
			let feed = try await RSSFeed(url: feedURL)
			guard let channel = feed.channel else { return [] }
			channelCache.setObject(ChannelBox(channel), forKey: podcast.feedURL as NSString)
			return parseEpisodes(channel: channel, podcast: podcast)
		} catch {
			NSLog("API: RSS feed parse failed for \(podcast.feedURL) — \(error.localizedDescription)")
			return []
		}
	}

	// MARK: - Parsing

	private static func parseSearchResponse(_ data: Data?) -> [Podcast] {
		guard let data,
			  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let results = root["results"] as? [[String: Any]]
		else {
			return []
		}

		return results.compactMap { item -> Podcast? in
			guard let kind = item["kind"] as? String,
				  kind.lowercased() == "podcast"
			else {
				return nil
			}
			return Podcast(json: item)
		}
	}

	private func parseEpisodes(channel: RSSFeedChannel, podcast: Podcast) -> [Episode] {
		guard let items = channel.items else { return [] }
		return items.map { item in
			var episode = Episode(feed: item)
			if episode.artwork == nil {
				episode.artwork = podcast.artwork
			}
			return episode
		}
	}

	// MARK: - Threading

	private func deliverOnMain<T>(_ value: T, to completion: @escaping (T) -> Void) {
		DispatchQueue.main.async { completion(value) }
	}

	// MARK: - Constants

	private enum Endpoints {
		static let iTunesSearch = "https://itunes.apple.com/search"
	}

	/// `NSCache` requires class keys/values. Wrap the FeedKit struct so it can
	/// live in the cache without bridging through `AnyObject`.
	private final class ChannelBox {
		let channel: RSSFeedChannel
		init(_ channel: RSSFeedChannel) { self.channel = channel }
	}
}
