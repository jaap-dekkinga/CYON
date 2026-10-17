//
//  CYOA.swift
//  CYON
//
//  Choose-Your-Own-Adventure support, ported from pp_turl_iOS (dev_OBS).
//  Copyright © 2022-2026 TuneURL Inc. All rights reserved.
//

import Alamofire
import Foundation

/// One branch a listener can pick at a CYOA choice moment.
///
/// Backed by the `get-cyoa-mp3` endpoint, which returns rows of
/// `{ "tuneurl_id": …, "options": …, "mp3_url": … }`.
struct CYOAOption: Equatable {
	let tuneURLID: String
	/// Button label shown to the listener (the backend's `options` field).
	let label: String
	let mp3URL: URL

	init?(json: [String: Any]) {
		guard let urlString = (json["mp3_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
			  urlString.lowercased().hasPrefix("https://"),
			  let url = URL(string: urlString)
		else {
			return nil
		}
		self.mp3URL = url

		// tuneurl_id may arrive as a string or a number
		if let id = json["tuneurl_id"] as? String {
			self.tuneURLID = id
		} else if let id = json["tuneurl_id"] as? NSNumber {
			self.tuneURLID = id.stringValue
		} else {
			self.tuneURLID = ""
		}

		let rawLabel = (json["options"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		self.label = rawLabel.isEmpty ? url.deletingPathExtension().lastPathComponent : rawLabel
	}

	/// Episode title used for the chosen branch in the player.
	var displayTitle: String {
		let name = mp3URL.deletingPathExtension().lastPathComponent
			.replacingOccurrences(of: "_", with: " ")
			.replacingOccurrences(of: "-", with: " ")
		return name.isEmpty ? label : name.capitalized
	}
}

enum CYOA {

	/// TuneURL match `type` values that mean "show a choice".
	static func isCYOA(type: String) -> Bool {
		return type.lowercased() == "cyoa"
	}

	/// Seconds the listener gets to choose before the default branch plays.
	static let choiceCountdown = 20
}

extension API {

	/// Fetch the branches registered for a CYOA TuneURL.
	///
	/// Delivers on the main queue. Returns an empty array on any failure
	/// (network, 404 "Mp3 does not exist…", unexpected JSON) so callers can
	/// fall back to the trigger's default URL.
	func getCYOAOptions(tuneURLID: Int, completion: @escaping ([CYOAOption]) -> Void) {
		getCYOAOptions(tuneURLID: tuneURLID, attemptsLeft: 3, completion: completion)
	}

	/// The dev backend intermittently answers 400 "Error in processing your
	/// request" for valid IDs, so retry a couple of times before giving up.
	private func getCYOAOptions(tuneURLID: Int, attemptsLeft: Int, completion: @escaping ([CYOAOption]) -> Void) {
		AF.request(
			CYOAEndpoints.getCYOAMp3,
			method: .get,
			parameters: ["tuneurl_id": String(tuneURLID)],
			encoding: URLEncoding.queryString
		)
		.validate(statusCode: 200 ..< 300)
		.responseData { response in
			let options = Self.parseCYOAOptions(response.data)
			let status = response.response?.statusCode ?? -1
			NSLog("[CYON-CYOA] get-cyoa-mp3 id=\(tuneURLID) status=\(status) options=\(options.count) attemptsLeft=\(attemptsLeft - 1)")
			if options.isEmpty, status != 404, attemptsLeft > 1 {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
					self.getCYOAOptions(tuneURLID: tuneURLID, attemptsLeft: attemptsLeft - 1, completion: completion)
				}
				return
			}
			DispatchQueue.main.async { completion(options) }
		}
	}

	private static func parseCYOAOptions(_ data: Data?) -> [CYOAOption] {
		guard let data,
			  let root = try? JSONSerialization.jsonObject(with: data)
		else {
			return []
		}

		// Accept a bare array or an object wrapping it in "data".
		let rows: [[String: Any]]
		if let array = root as? [[String: Any]] {
			rows = array
		} else if let object = root as? [String: Any], let array = object["data"] as? [[String: Any]] {
			rows = array
		} else {
			return []
		}

		return rows.compactMap(CYOAOption.init(json:))
	}

	private enum CYOAEndpoints {
		static let getCYOAMp3 = "https://pnz3vadc52.execute-api.us-east-2.amazonaws.com/dev/get-cyoa-mp3"
	}
}
