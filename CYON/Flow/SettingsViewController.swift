//
//  SettingsViewController.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import UIKit
import TuneURL

class SettingsViewController: UIViewController {

	@IBOutlet var autoDeleteSwitch: UISwitch!
	@IBOutlet var autoDownloadSwitch: UISwitch!

	// MARK: - Actions

	@IBAction func autoDeleteChanged(_ sender: UISwitch) {
		// TODO: implement this
	}

	@IBAction func autoDownloadChanged(_ sender: UISwitch) {
		// TODO: implement this
	}

	@IBAction func debugSelfPlay(_ sender: Any) {
	    guard let url = Bundle.main.url(forResource: "Trigger-Sound", withExtension: "wav") else {
	        NSLog("[CYON-TURL] SELF-TEST: trigger file missing from bundle")
	        return
	    }
	    NSLog("[CYON-TURL] SELF-TEST: playing trigger sound as episode")
	    Player.shared.currentFileURL = url
	    Detector.processAudio(for: url) { matches in
	        NSLog("[CYON-TURL] SELF-TEST DONE matches=\(matches.count)")
	        for (i, m) in matches.enumerated() {
	            NSLog("[CYON-TURL] SELF-TEST match[\(i)] time=\(m.time)s matchPct=\(m.matchPercentage)")
	        }
	    }
	}
}

