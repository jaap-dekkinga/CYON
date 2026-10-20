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
	private var playerPinnedToTabBar = false

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

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		pinPlayerToTabBar()
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
		self.view.addSubview(playerContainer)
		playerContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
		playerContainer.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
		playerContainer.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true

		// create the maximized player constraints
		playerMaximizedConstraint = playerContainer.topAnchor.constraint(equalTo: self.view.topAnchor)

		// create the minimized and collapsed constraints, and keep the tab bar in front
		pinPlayerToTabBar()

		// initially collapsed
		playerCollapsedConstraint.isActive = true
	}

	/// (Re)creates the constraints that sit the player on top of the tab bar, and brings the
	/// tab bar in front of the player. On iPadOS 18 the tab bar is only added to this view
	/// during the first layout pass, after viewDidLoad, so this runs again from
	/// viewDidLayoutSubviews once it appears.
	private func pinPlayerToTabBar() {
		guard let playerContainer = player.view else {
			return
		}

		let tabBarInView = tabBar.isDescendant(of: view)
		if playerContainer.superview == view && tabBarInView {
			bringTabBarToFront()
		}
		if playerPinnedToTabBar == tabBarInView && playerCollapsedConstraint != nil {
			return
		}
		playerPinnedToTabBar = tabBarInView

		// remember which state was active, then rebuild against the current anchor
		let collapsedWasActive = playerCollapsedConstraint?.isActive ?? false
		let minimizedWasActive = playerMinimizedConstraint?.isActive ?? false
		playerCollapsedConstraint?.isActive = false
		playerMinimizedConstraint?.isActive = false

		playerMinimizedConstraint = playerContainer.topAnchor.constraint(equalTo: tabBarTopAnchor, constant: -Player.miniPlayerHeight)
		playerCollapsedConstraint = playerContainer.topAnchor.constraint(equalTo: tabBarTopAnchor, constant: -1)

		playerCollapsedConstraint.isActive = collapsedWasActive
		playerMinimizedConstraint.isActive = minimizedWasActive

		// the mini player is pinned to the same anchor, so re-pin it if it is showing
		if minimizedWasActive {
			player.hideMiniPlayer()
			player.showMiniPlayer(above: tabBarTopAnchor)
		}
	}

	/// Brings the tab bar (or the subview of `view` that contains it) in front of the player.
	private func bringTabBarToFront() {
		var front: UIView = tabBar
		while let parent = front.superview, parent != view {
			front = parent
		}
		if front.superview == view {
			view.bringSubviewToFront(front)
		}
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
