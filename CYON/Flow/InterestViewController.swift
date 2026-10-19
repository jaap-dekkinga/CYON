//
//  InterestViewController.swift
//  Podcast
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 1/28/22.
//  Copyright © 2022 TuneURL Inc. All rights reserved.
//

import TuneURL
import UIKit
import WebKit

class InterestViewController: UIViewController {

	// interface
	@IBOutlet weak var actionLabel: UILabel!
	@IBOutlet weak var webView: WKWebView!

	// public
	var userInteracted = false

	// private
	private var tuneURL: TuneURL.Match?

	// CYOA (choose your own adventure)
	private var cyoaOptions = [CYOAOption]()
	private var cyoaCountdown = CYOA.choiceCountdown
	private var cyoaTimer: Timer?
	private var cyoaChoiceMade = false
	private let cyoaContainer = UIView()
	private let cyoaStack = UIStackView()
	private let cyoaCountdownLabel = UILabel()

	// MARK: -

	class func create(with tuneURL: TuneURL.Match, wasUserInitiated: Bool) -> InterestViewController {
		let storyboard = UIStoryboard(name: "TuneURL", bundle: nil)
		let viewController = storyboard.instantiateViewController(withIdentifier: "InterestViewController") as! InterestViewController
		viewController.tuneURL = tuneURL
		return viewController
	}

	// MARK: - UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()
		webView.layer.cornerRadius = 16.0
		webView.layer.masksToBounds = true
		if let tuneURL = self.tuneURL {
			if CYOA.isCYOA(type: tuneURL.type) {
				setupCYOA(tuneURL)
			} else {
				setupTuneURL(tuneURL)
			}
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		cyoaTimer?.invalidate()
		cyoaTimer = nil
	}

	// MARK: - Actions

	@IBAction func close(_ sender: AnyObject?) {
		self.dismiss(animated: true, completion: nil)
	}

	@IBAction func openWebsite(_ sender: AnyObject?) {
		performAction()
	}

	// MARK: - Private

	private func performAction() {
		// safety check
		guard let tuneURL = self.tuneURL else {
			return
		}

		switch (tuneURL.type) {

			case "coupon":
				// TODO: save the coupon
				break

			case "open_page":
				// open web page
				if let itemURL = URL(string: tuneURL.info) {
					UIApplication.shared.open(itemURL, options: [:], completionHandler: nil)
				}

			case "phone":
				// TODO: open the phone number url
//				if let phoneURL = tuneURL.phoneURL {
//					UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
//				}
				break

			case "poll":
				// TODO: add polls
				break

			case "sms":
				// TODO: open message panel
				break

			case "save_page":
				// TODO: find out how this should work
				break

			default:
				break
		}

		// close
		self.dismiss(animated: true, completion: nil)
	}

	private func setupTuneURL(_ tuneURL: TuneURL.Match) {
		// setup the action message
		var actionMessage = ""

		switch (tuneURL.type) {
			case "coupon":
				actionMessage = "Tap to Save Coupon"
				webView.isHidden = true

			case "open_page":
				actionMessage = "Tap to Open"
				if let url = URL(string: tuneURL.info) {
					webView.load(URLRequest(url: url))
				}

			case "phone":
				actionMessage = "Tap to Call Now"
				webView.isHidden = true

			case "poll":
				webView.isHidden = true

			case "save_page":
				actionMessage = "Save bookmark for \(tuneURL.info)?"
				if let url = URL(string: tuneURL.info) {
					webView.load(URLRequest(url: url))
				}

			case "sms":
				actionMessage = "Tap to Message Now"
				webView.isHidden = true

			default:
				break
		}

		actionLabel.text = actionMessage
	}

	// MARK: - CYOA

	/// Build the choice sheet over the standard interest UI.
	private func setupCYOA(_ tuneURL: TuneURL.Match) {
		// the countdown governs this sheet, not the player's presentation window
		userInteracted = true
		isModalInPresentation = true
		webView.isHidden = true

		cyoaContainer.translatesAutoresizingMaskIntoConstraints = false
		cyoaContainer.backgroundColor = .systemBackground
		view.addSubview(cyoaContainer)
		NSLayoutConstraint.activate([
			cyoaContainer.topAnchor.constraint(equalTo: view.topAnchor),
			cyoaContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			cyoaContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			cyoaContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])

		let titleLabel = UILabel()
		titleLabel.text = "What happens next?"
		titleLabel.font = .preferredFont(forTextStyle: .title2).withBold()
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 0

		let subtitleLabel = UILabel()
		subtitleLabel.text = "Choose your path"
		subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.textAlignment = .center

		let spinner = UIActivityIndicatorView(style: .medium)
		spinner.startAnimating()

		cyoaStack.axis = .vertical
		cyoaStack.spacing = 16
		cyoaStack.alignment = .fill
		cyoaStack.addArrangedSubview(spinner)

		cyoaCountdownLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
		cyoaCountdownLabel.textColor = .secondaryLabel
		cyoaCountdownLabel.textAlignment = .center
		cyoaCountdownLabel.numberOfLines = 0

		let content = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cyoaStack, cyoaCountdownLabel])
		content.axis = .vertical
		content.spacing = 12
		content.setCustomSpacing(32, after: subtitleLabel)
		content.setCustomSpacing(32, after: cyoaStack)
		content.translatesAutoresizingMaskIntoConstraints = false
		cyoaContainer.addSubview(content)
		NSLayoutConstraint.activate([
			content.centerYAnchor.constraint(equalTo: cyoaContainer.safeAreaLayoutGuide.centerYAnchor),
			content.leadingAnchor.constraint(equalTo: cyoaContainer.safeAreaLayoutGuide.leadingAnchor, constant: 32),
			content.trailingAnchor.constraint(equalTo: cyoaContainer.safeAreaLayoutGuide.trailingAnchor, constant: -32),
		])

		NSLog("[CYON-CYOA] choice sheet id=\(tuneURL.id) default=\"\(tuneURL.info)\"")

		API.shared.getCYOAOptions(tuneURLID: tuneURL.id) { [weak self] options in
			self?.showCYOAOptions(options)
		}
	}

	private func showCYOAOptions(_ options: [CYOAOption]) {
		guard cyoaChoiceMade == false else { return }

		cyoaOptions = options
		cyoaStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

		if options.isEmpty {
			// nothing registered -- fall back to the trigger's default branch (or keep listening)
			let label = UILabel()
			label.text = (defaultCYOAURL() != nil) ? "Continuing the story…" : "No choices available"
			label.textAlignment = .center
			label.textColor = .secondaryLabel
			cyoaStack.addArrangedSubview(label)
			cyoaCountdown = 3
		} else {
			for (index, option) in options.enumerated() {
				var config = UIButton.Configuration.filled()
				config.title = option.label
				config.baseBackgroundColor = UIColor(named: "Item-Active") ?? .systemBlue
				config.baseForegroundColor = .white
				config.cornerStyle = .medium
				config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
				config.titleAlignment = .center
				let button = UIButton(configuration: config)
				button.titleLabel?.numberOfLines = 0
				button.tag = index
				button.addTarget(self, action: #selector(cyoaOptionTapped(_:)), for: .touchUpInside)
				cyoaStack.addArrangedSubview(button)
			}
			cyoaCountdown = CYOA.choiceCountdown
		}

		updateCYOACountdownLabel()
		cyoaTimer?.invalidate()
		cyoaTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			self?.cyoaTick()
		}
	}

	private func cyoaTick() {
		cyoaCountdown -= 1
		if cyoaCountdown <= 0 {
			cyoaTimer?.invalidate()
			cyoaTimer = nil
			chooseDefaultCYOA()
		} else {
			updateCYOACountdownLabel()
		}
	}

	private func updateCYOACountdownLabel() {
		if cyoaOptions.isEmpty {
			cyoaCountdownLabel.text = nil
		} else {
			cyoaCountdownLabel.text = "The story picks for you in \(cyoaCountdown)s"
		}
	}

	@objc private func cyoaOptionTapped(_ sender: UIButton) {
		guard sender.tag < cyoaOptions.count else { return }
		let option = cyoaOptions[sender.tag]
		NSLog("[CYON-CYOA] chose option[\(sender.tag)] \"\(option.label)\" -> \(option.mp3URL.lastPathComponent)")
		finishCYOA(url: option.mp3URL, title: option.displayTitle)
	}

	/// Countdown ran out: play the trigger's default URL, else the first option.
	private func chooseDefaultCYOA() {
		if let url = defaultCYOAURL() {
			let match = cyoaOptions.first { $0.mp3URL == url }
			NSLog("[CYON-CYOA] timeout -> default \(url.lastPathComponent)")
			finishCYOA(url: url, title: match?.displayTitle)
		} else if let first = cyoaOptions.first {
			NSLog("[CYON-CYOA] timeout -> first option \(first.mp3URL.lastPathComponent)")
			finishCYOA(url: first.mp3URL, title: first.displayTitle)
		} else {
			NSLog("[CYON-CYOA] timeout with no options -- continuing current episode")
			cyoaChoiceMade = true
			dismiss(animated: true)
		}
	}

	private func defaultCYOAURL() -> URL? {
		guard let info = tuneURL?.info.trimmingCharacters(in: .whitespacesAndNewlines),
			  info.lowercased().hasPrefix("https://")
		else {
			return nil
		}
		return URL(string: info)
	}

	private func finishCYOA(url: URL, title: String?) {
		guard cyoaChoiceMade == false else { return }
		cyoaChoiceMade = true
		cyoaTimer?.invalidate()
		cyoaTimer = nil
		dismiss(animated: true) {
			Player.shared.playCYOABranch(url: url, title: title)
		}
	}

}

private extension UIFont {
	func withBold() -> UIFont {
		guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
		return UIFont(descriptor: descriptor, size: 0)
	}
}
