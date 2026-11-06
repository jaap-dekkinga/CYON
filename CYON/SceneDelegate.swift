//
//  SceneDelegate.swift
//  CYON
//
//  iOS 27 requires the UIScene life cycle: apps built with the latest SDK that
//  don't adopt it fail to launch. The window and root view controller come from
//  Main.storyboard via UISceneStoryboardFile in Info-CYON.plist, so UIKit creates
//  and shows the window itself; this class only has to exist and hold it.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		// The storyboard sets up `window`; nothing else is needed at connect time.
		guard scene is UIWindowScene else {
			return
		}
	}

}
