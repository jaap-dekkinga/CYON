//
//  SearchViewController.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import UIKit
import TuneURL

class SearchViewController: BaseTableViewController {

	// MARK: - Debug test files
	// Uncomment ONE to select which bundled .wav the "repo" search shortcut plays.
	private static let debugTestFile = "TuneURL-IBC_CYOA_1_ben"
	// private static let debugTestFile = "podcast_full"
	// private static let debugTestFile = "podcast_intro"
	// private static let debugTestFile = "what_is_tuneurl"

	// Type "ashford" to start the Ashford House Affair CYOA test from its first episode.
	private static let cyoaTestStartURL = URL(string: "https://tuneurl-choose-to-be-curious.s3.us-east-2.amazonaws.com/01_the_locked_room.mp3")!

	// MARK: - Properties

	fileprivate let cellID = "PodcastCell"

	var headerString = "Search podcasts by title or artist name."

	private var isSearching = false
	private var podcasts = [Podcast]()

	lazy var searchController: UISearchController = {
	    let search = UISearchController(searchResultsController: nil)
	    search.searchBar.delegate = self
	    search.hidesBottomBarWhenPushed = true
	    search.searchBar.autocorrectionType = .no
	    search.searchBar.autocapitalizationType = .none
	    search.searchBar.spellCheckingType = .no
	    return search
	}()

	// MARK: - UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()

		// setup the search controller
		navigationItem.searchController = searchController
		navigationItem.hidesSearchBarWhenScrolling = false
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if (segue.identifier == "ShowEpisodesSegue"),
		   let episodesController = segue.destination as? EpisodesViewController,
		   let podcastCell = sender as? PodcastCell {
			episodesController.podcast = podcastCell.podcast
		}
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return podcasts.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as! PodcastCell
		cell.podcast = podcasts[indexPath.row]
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return (podcasts.count == 0) ? 250.0 : 0.0
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return isSearching ? SearchLoadingHeader() : TextTableViewHeader(text: headerString)
	}
}

// MARK: - Search Bar Delegate

extension SearchViewController: UISearchBarDelegate {

	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		// --- Debug shortcut: type "repo" to play a bundled test file ---
		if let text = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), text == "repo" {
			guard let url = Bundle.main.url(forResource: Self.debugTestFile, withExtension: "wav") else {
				NSLog("[CYON-TURL] debug file '\(Self.debugTestFile).wav' not in bundle — check target membership")
				searchController.dismiss(animated: true, completion: nil)
				return
			}
			NSLog("[CYON-TURL] SEARCH SHORTCUT triggered — playing \(Self.debugTestFile).wav")
			Player.debugPlayFile(url, title: Self.debugTestFile)
			searchController.dismiss(animated: true, completion: nil)
			return
		}
		// --- Debug shortcut: type "ashford" to start the CYOA test story ---
		if let text = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), text == "ashford" {
			NSLog("[CYON-CYOA] SEARCH SHORTCUT triggered — starting \(Self.cyoaTestStartURL.lastPathComponent)")
			Player.shared.playCYOABranch(url: Self.cyoaTestStartURL, title: "The Locked Room")
			Player.shared.maximizePlayer()
			searchController.dismiss(animated: true, completion: nil)
			return
		}
		// --- End debug shortcut ---

		self.podcasts = []
		isSearching = true
		tableView.reloadData()

		// get the search text
		guard let searchText = searchBar.text,
			  (searchText.isEmpty == false) else {
			return
		}

		API.shared.searchPodcasts(searchText: searchText) {
			[weak self] (searchedPodcasts) in

			// safety check
			guard let self = self else {
				return
			}

			self.podcasts = searchedPodcasts
			self.isSearching = false
			self.headerString = "We couldn't find any results for\n\n\"\(searchText)\".\n\nPlease try again."
			self.tableView.reloadData()
		}

		searchController.dismiss(animated: true, completion: nil)
	}

	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		headerString = "Search the largest library of podcasts by title or artist's name."
		tableView.reloadData()
	}
}
