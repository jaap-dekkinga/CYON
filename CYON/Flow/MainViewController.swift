//
//  MainViewController.swift
//  Podcast
//
//  Created on 10/14/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import UIKit

class MainViewController: UITabBarController {

	// public
	let player = Player.shared

	// private
	private var playerCollapsedConstraint: NSLayoutConstraint!
	private var playerMaximizedConstraint: NSLayoutConstraint!
	private var playerMinimizedConstraint: NSLayoutConstraint!

	// MARK: - Init

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		useClassicTabBarOnPad()
	}

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		useClassicTabBarOnPad()
	}

	// MARK: - UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()
		setupPlayer()
	}

	// MARK: - Tab bar anchor

	/// The anchor the player sits on top of. On iPadOS 18+ the classic tab bar can be
	/// replaced by the floating tab bar, which lives outside this view; constraining to it
	/// crashes ("no common ancestor"). Fall back to the bottom of the safe area then.
	var tabBarTopAnchor: NSLayoutYAxisAnchor {
		if tabBar.isDescendant(of: view) {
			return tabBar.topAnchor
		}
		return view.safeAreaLayoutGuide.bottomAnchor
	}

	// MARK: - Private

	/// iPadOS 18 shows a floating tab bar at the top in regular width. The player is built
	/// around a bottom tab bar, so keep the classic one on iPad.
	private func useClassicTabBarOnPad() {
		if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
			traitOverrides.horizontalSizeClass = .compact
		}
	}

	fileprivate func setupPlayer() {
		guard let playerContainer = player.view else {
			return
		}

		player.delegate = self

		// setup the constraints on the player container
		playerContainer.translatesAutoresizingMaskIntoConstraints = false
		if self.tabBar.isDescendant(of: self.view) {
			self.view.insertSubview(playerContainer, belowSubview: self.tabBar)
		} else {
			self.view.addSubview(playerContainer)
		}
		playerContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
		playerContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
		playerContainer.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true

		// create the maximized player constraints
		playerMaximizedConstraint = playerContainer.topAnchor.constraint(equalTo: self.view.topAnchor)

		// create the minimized player constraints
		playerMinimizedConstraint = playerContainer.topAnchor.constraint(equalTo: self.tabBarTopAnchor, constant: -Player.miniPlayerHeight)

		// create the collapsed player constraints
		playerCollapsedConstraint = playerContainer.topAnchor.constraint(equalTo: self.tabBarTopAnchor, constant: -1)

		// initially collapsed
		playerCollapsedConstraint.isActive = true
	}

}

// MARK: - Player Delegate

extension MainViewController: PlayerDelegate {

	func playerMaximize() {
		UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
			[unowned self] in

			player.hideMiniPlayer()
			playerCollapsedConstraint.isActive = false
			playerMaximizedConstraint.isActive = true
			playerMinimizedConstraint.isActive = false
			player.showFullPlayer()
			player.notifyContentInsetsShouldChange()

			self.tabBar.isHidden = true
		})
	}

	func playerMinimize() {
		UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
			[unowned self] in

			player.hideFullPlayer()
			playerCollapsedConstraint.isActive = false
			playerMaximizedConstraint.isActive = false
			playerMinimizedConstraint.isActive = true
			player.showMiniPlayer(above: self.tabBarTopAnchor)
			player.notifyContentInsetsShouldChange()

			self.tabBar.isHidden = false
		})
	}

}
