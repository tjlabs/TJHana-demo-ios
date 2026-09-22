//
//  DebugTitleView.swift
//  TJHanaDemo
//
//  A navigation-bar titleView that fires `onLongPress` after the user holds it
//  for `requiredDuration`. It measures the hold with direct touch handling
//  (touchesBegan/Ended) instead of a UIGestureRecognizer, because gesture
//  recognizers are not delivered reliably inside a UINavigationBar's titleView.
//

import UIKit

final class DebugTitleView: UIView {

    var onLongPress: (() -> Void)?
    var requiredDuration: TimeInterval = 3.0

    private var holdTimer: Timer?

    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        label.text = title
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            // Explicit, generous hit area so the touch reliably lands on this view.
            heightAnchor.constraint(equalToConstant: 44),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        setPressed(true)
        startHoldTimer()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setPressed(false)
        cancelHoldTimer()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setPressed(false)
        cancelHoldTimer()
    }

    private func setPressed(_ pressed: Bool) {
        // Immediate visual feedback so it is obvious the touch is being received.
        label.textColor = pressed ? .systemBlue : .label
    }

    private func startHoldTimer() {
        cancelHoldTimer()
        let timer = Timer(timeInterval: requiredDuration, repeats: false) { [weak self] _ in
            self?.cancelHoldTimer()
            self?.onLongPress?()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }
}
