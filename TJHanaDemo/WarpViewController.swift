
import UIKit
import TJHanaSDK

class WarpViewController: UIViewController, TJWarpViewDelegate {
    private enum SelectionIntervalState {
        case pending
        case applied
        case invalidInput
    }
    
    func onInitSuccess(_ view: TJHanaSDK.TJWarpView, _ isSuccess: Bool, _ code: TJHanaSDK.WarpInitErrorCode?) {
        if isSuccess {
            isWarpInitialized = true
            self.warpView?.startService()
            self.warpView?.configureFrame(to: self.floatingContainerView, warpImage: UIImage(named: "ic_warp"))
            applySelectionInterval(pendingSelectionInterval, state: .applied)
        } else {
            updateSelectionIntervalStatus(
                text: "Warp 초기화 실패로 interval을 적용하지 못했습니다. code: \(String(describing: code))",
                color: .systemRed
            )
        }
    }
    
    func onWarpSuccess(_ view: TJHanaSDK.TJWarpView, _ isSuccess: Bool, _ code: TJHanaSDK.WarpErrorCode?) {
        print("(WarpViewController) onWarpSuccess -> isSuccess:\(isSuccess), code:\(String(describing: code))")
    }
    
    func onClick(_ view: TJHanaSDK.TJWarpView, warpWards: [TJHanaSDK.WarpWard]) {
        print("(WarpViewController) onClick -> warpWards:\(warpWards)")
        let wardNames = warpWards.map(\.name)
        let uniqueWardNames = wardNames.reduce(into: [String]()) { result, name in
            if !result.contains(name) {
                result.append(name)
            }
        }

        DispatchQueue.main.async {
            self.updateWardNames(uniqueWardNames)
        }
    }
    
    func onWarpSelectionChanged(_ view: TJHanaSDK.TJWarpView, warpWards: [TJHanaSDK.WarpWard]) {
        print("(WarpViewController) onWarpSelectionChanged -> warpWards:\(warpWards)")
        let wardNames = warpWards.map(\.name)
        let uniqueWardNames = wardNames.reduce(into: [String]()) { result, name in
            if !result.contains(name) {
                result.append(name)
            }
        }

        DispatchQueue.main.async {
            self.updateSelectionWardNames(uniqueWardNames)
        }
    }
    
    private let warpUserId = "hana-example-user"
    private let floatingContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    private let wardListTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = "Detected Wards"
        return label
    }()
    private let selectionIntervalTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = "Selection Interval (seconds)"
        return label
    }()
    private let selectionIntervalTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .roundedRect
        textField.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
        textField.keyboardType = .decimalPad
        textField.placeholder = "예: 0.5"
        textField.text = "1.0"
        return textField
    }()
    private lazy var applyIntervalButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Apply", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .label
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        button.addTarget(self, action: #selector(didTapApplyInterval), for: .touchUpInside)
        return button
    }()
    private let selectionIntervalStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "현재 설정값: 1.0초"
        return label
    }()
    private lazy var selectionIntervalInputStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [selectionIntervalTextField, applyIntervalButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .fill
        return stackView
    }()
    private lazy var selectionIntervalContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            selectionIntervalTitleLabel,
            selectionIntervalInputStackView,
            selectionIntervalStatusLabel
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.backgroundColor = .secondarySystemBackground
        stackView.layer.cornerRadius = 14
        stackView.layer.masksToBounds = true
        return stackView
    }()
    private let wardListLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = "WarpView를 탭하면 ward 목록이 표시됩니다."
        return label
    }()
    private lazy var wardListContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [wardListTitleLabel, wardListLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.backgroundColor = .secondarySystemBackground
        stackView.layer.cornerRadius = 14
        stackView.layer.masksToBounds = true
        return stackView
    }()
    private let selectionWardListTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.text = "Selection Changed Wards"
        return label
    }()
    private let selectionWardListLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = "selection이 변경되면 ward 목록이 표시됩니다."
        return label
    }()
    private lazy var selectionWardListContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [selectionWardListTitleLabel, selectionWardListLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.backgroundColor = .secondarySystemBackground
        stackView.layer.cornerRadius = 14
        stackView.layer.masksToBounds = true
        return stackView
    }()

    private var warpView: TJWarpView? = TJWarpView()
    private var pendingSelectionInterval: TimeInterval = 1.0
    private var isWarpInitialized = false
    private var hasReleasedWarpResources = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Warp"
        selectionIntervalTextField.delegate = self
        setupFloatingWarpView()
        initializeWarpView()
        setupKeyboardDismissGesture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            releaseWarpResources()
        }
    }

    deinit {
        releaseWarpResources()
    }

    private func setupFloatingWarpView() {
        print("(WarpViewController) setupFloatingWarpView")
        view.addSubview(selectionIntervalContainerView)
        view.addSubview(floatingContainerView)
        view.addSubview(wardListContainerView)
        view.addSubview(selectionWardListContainerView)

        NSLayoutConstraint.activate([
            selectionIntervalContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            selectionIntervalContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            selectionIntervalContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            applyIntervalButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
            floatingContainerView.widthAnchor.constraint(equalToConstant: 80),
            floatingContainerView.heightAnchor.constraint(equalToConstant: 80),
            floatingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingContainerView.topAnchor.constraint(equalTo: selectionIntervalContainerView.bottomAnchor, constant: 40),

            wardListContainerView.topAnchor.constraint(equalTo: floatingContainerView.bottomAnchor, constant: 24),
            wardListContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            wardListContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            selectionWardListContainerView.topAnchor.constraint(equalTo: wardListContainerView.bottomAnchor, constant: 16),
            selectionWardListContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            selectionWardListContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            selectionWardListContainerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        view.layoutIfNeeded()
    }

    private func initializeWarpView() {
        print("(WarpViewController) initializeWarpView")
        warpView?.delegate = self
        warpView?.initialize(id: warpUserId, forceUpdate: true)
    }

    private func updateWardNames(_ names: [String]) {
        if names.isEmpty {
            wardListLabel.text = "선택된 ward 정보가 없습니다."
            return
        }

        wardListLabel.text = names.enumerated()
            .map { index, name in "\(index + 1). \(name)" }
            .joined(separator: "\n")
    }

    private func updateSelectionWardNames(_ names: [String]) {
        if names.isEmpty {
            selectionWardListLabel.text = "선택된 ward 정보가 없습니다."
            return
        }

        selectionWardListLabel.text = names.enumerated()
            .map { index, name in "\(index + 1). \(name)" }
            .joined(separator: "\n")
    }

    private func setupKeyboardDismissGesture() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }

    private func applySelectionInterval(_ seconds: TimeInterval, state: SelectionIntervalState) {
        pendingSelectionInterval = seconds
        selectionIntervalTextField.text = String(format: "%.2f", seconds)

        switch state {
        case .pending:
            updateSelectionIntervalStatus(
                text: "초기화 전입니다. \(String(format: "%.2f", seconds))초로 대기 중이며, 초기화가 끝나면 자동 적용됩니다.",
                color: .secondaryLabel
            )
        case .applied:
            warpView?.setSelectionInterval(seconds: seconds)
            updateSelectionIntervalStatus(
                text: "현재 설정값: \(String(format: "%.2f", seconds))초",
                color: .systemGreen
            )
        case .invalidInput:
            updateSelectionIntervalStatus(
                text: "0 이상의 숫자를 입력해주세요.",
                color: .systemRed
            )
        }
    }

    private func updateSelectionIntervalStatus(text: String, color: UIColor) {
        selectionIntervalStatusLabel.text = text
        selectionIntervalStatusLabel.textColor = color
    }

    @objc private func didTapApplyInterval() {
        dismissKeyboard()

        guard
            let text = selectionIntervalTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty,
            let seconds = TimeInterval(text),
            seconds >= 0
        else {
            applySelectionInterval(pendingSelectionInterval, state: .invalidInput)
            return
        }

        let nextState: SelectionIntervalState = isWarpInitialized ? .applied : .pending
        applySelectionInterval(seconds, state: nextState)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func releaseWarpResources() {
        guard !hasReleasedWarpResources else { return }
        hasReleasedWarpResources = true

        warpView?.delegate = nil
        warpView?.stopService()
        warpView = nil
        isWarpInitialized = false
    }
}

extension WarpViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapApplyInterval()
        return true
    }
}
