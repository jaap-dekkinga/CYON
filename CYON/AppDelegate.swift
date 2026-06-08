//
//  AppDelegate.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import UIKit
import AVFoundation
import TuneURL

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	// static
	static var shared: AppDelegate = {
		UIApplication.shared.delegate as! AppDelegate
	}()

	static var documentsURL: URL = {
		// get the documents folder
		guard let url = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
			return URL(fileURLWithPath: NSTemporaryDirectory())
		}
		return url
	}()

	static var uniqueID: String = {
		// get the uuid
		if let uuid = UserDefaults.standard.string(forKey: "Unique ID") {
			return uuid
		}
		// create a new uuid
		let uuid = UUID().uuidString
		UserDefaults.standard.set(uuid, forKey: "Unique ID")
		return uuid
	}()

	// public
	var window: UIWindow?

	// MARK: -

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
		setupTuneURLTrigger()
		setupAppearance()
		return true
	}

	func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
		API.shared.clearCache()
	}

	// MARK: - Private

	private func setupAppearance() {
		// setup the navigation bar appearance
		UINavigationBar.appearance().prefersLargeTitles = true
		// setup the tab bar appearance
		let tabBarAppearance = UITabBarAppearance()
		tabBarAppearance.configureWithTransparentBackground()
		tabBarAppearance.backgroundColor = .clear
		tabBarAppearance.backgroundEffect = nil
		UITabBar.appearance().standardAppearance = tabBarAppearance
		if #available(iOS 15.0, *) {
			UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
		}
	}

	private func setupTuneURLTrigger() {
		guard let url = Bundle.main.url(forResource: "Trigger-Sound", withExtension: "wav") else {
			return
		}

		Detector.setTrigger(url)
	}

}
