//
//  DebugManager.swift
//  TJHanaDemo
//
//  Holds the app-wide debug-mode state and shows a small, non-interactive
//  floating indicator in the bottom-right corner of the key window so the
//  current mode is visible from every view controller.
//

import UIKit

final class DebugManager {
    static let shared = DebugManager()

    /// Posted whenever `isDebugMode` changes so UI can update itself.
    static let didChangeNotification = Notification.Name("DebugManagerDidChangeNotification")

    private(set) var isDebugMode = false {
        didSet {
            guard oldValue != isDebugMode else { return }
            updateIndicator()
            NotificationCenter.default.post(name: DebugManager.didChangeNotification, object: nil)
        }
    }

    private weak var indicatorView: UIView?

    private init() {}

    func toggle() {
        isDebugMode.toggle()
    }

    private var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let windows = activeScene?.windows ?? []
        return windows.first { $0.isKeyWindow } ?? windows.first
    }

    private func updateIndicator() {
        if isDebugMode {
            showIndicator()
        } else {
            indicatorView?.removeFromSuperview()
            indicatorView = nil
        }
    }

    private func showIndicator() {
        guard indicatorView == nil, let window = keyWindow else { return }

        var config = UIButton.Configuration.filled()
        config.title = "DEBUG"
        config.baseBackgroundColor = .systemRed
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.buttonSize = .mini

        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = false
        button.alpha = 0.9
        button.translatesAutoresizingMaskIntoConstraints = false

        window.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        indicatorView = button
    }
}
