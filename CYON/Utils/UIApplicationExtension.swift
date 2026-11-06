//
//  UIApplicationExtension.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import UIKit

extension UIApplication {

	/// The key window of the foreground scene. Replaces the deprecated `keyWindow` and
	/// `AppDelegate.window`, which is nil once the app uses the UIScene life cycle.
	var currentKeyWindow: UIWindow? {
		let windowScenes = connectedScenes.compactMap { $0 as? UIWindowScene }
		let activeScene = windowScenes.first { $0.activationState == .foregroundActive }
			?? windowScenes.first { $0.activationState == .foregroundInactive }
			?? windowScenes.first
		return activeScene?.windows.first { $0.isKeyWindow } ?? activeScene?.windows.first
	}

	func addSubview(view: UIView) {
		let main = currentKeyWindow?.rootViewController
		main?.view.addSubview(view)
	}

}
