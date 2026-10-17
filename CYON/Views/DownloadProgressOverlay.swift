//
//  DownloadProgressOverlay.swift
//  CYON
//
//  Dimmed spinner + percentage shown over episode artwork while an episode
//  downloads before playback.
//  Copyright © 2026 TuneURL Inc. All rights reserved.
//

import UIKit

final class DownloadProgressOverlay: UIView {

	private let spinner = UIActivityIndicatorView(style: .medium)
	private let label = UILabel()
	private let showsLabel: Bool

	/// - Parameter compact: true for small artwork (mini player): spinner only.
	init(compact: Bool) {
		self.showsLabel = !compact
		super.init(frame: .zero)

		translatesAutoresizingMaskIntoConstraints = false
		backgroundColor = UIColor.black.withAlphaComponent(0.45)
		isUserInteractionEnabled = false
		isHidden = true
		alpha = 0

		spinner.color = .white
		spinner.hidesWhenStopped = false
		if !compact {
			spinner.style = .large
		}

		label.textColor = .white
		label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
		label.textAlignment = .center
		label.isHidden = compact

		let stack = UIStackView(arrangedSubviews: [spinner, label])
		stack.axis = .vertical
		stack.alignment = .center
		stack.spacing = 10
		stack.translatesAutoresizingMaskIntoConstraints = false
		addSubview(stack)
		NSLayoutConstraint.activate([
			stack.centerXAnchor.constraint(equalTo: centerXAnchor),
			stack.centerYAnchor.constraint(equalTo: centerYAnchor),
			stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
		])

		isAccessibilityElement = true
		accessibilityTraits = .updatesFrequently
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// Pin the overlay over `view`, matching its corner radius.
	func attach(to view: UIView) {
		view.addSubview(self)
		layer.cornerRadius = view.layer.cornerRadius
		layer.masksToBounds = true
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: view.topAnchor),
			bottomAnchor.constraint(equalTo: view.bottomAnchor),
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])
	}

	func show() {
		setProgress(nil)
		spinner.startAnimating()
		isHidden = false
		UIView.animate(withDuration: 0.2) { self.alpha = 1 }
	}

	/// - Parameter fraction: 0...1, or nil when the size isn't known yet.
	func setProgress(_ fraction: Double?) {
		let text: String
		if let fraction, fraction > 0 {
			text = "Downloading \(Int((min(fraction, 1) * 100).rounded()))%"
		} else {
			text = "Downloading…"
		}
		if showsLabel { label.text = text }
		accessibilityLabel = text
	}

	func showFailure() {
		spinner.stopAnimating()
		spinner.isHidden = true
		label.isHidden = false
		label.text = showsLabel ? "Download failed" : "!"
		accessibilityLabel = "Download failed"
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
			self?.hide()
		}
	}

	func hide() {
		UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
			// a show() may have started while this fade ran
			guard self.alpha == 0 else { return }
			self.isHidden = true
			self.spinner.stopAnimating()
			self.spinner.isHidden = false
			self.label.isHidden = !self.showsLabel
		}
	}
}
