
import UIKit
import TJHanaSDK

final class JupiterViewController: UIViewController, TJJupiterManagerDelegate {
    private let jupiterUserId = "hana-example-user"
    private var jupiterManager: TJJupiterManager?
    private var hasReleasedJupiterResources = false
    private var isServiceRunning = false

    private let jupiterMode: UserMode = .MODE_VEHICLE

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "시작 버튼을 눌러 차량(DR) 모드로 측위를 시작하세요."
        return label
    }()

    private lazy var startButton: UIButton = makeActionButton(
        title: "시작",
        backgroundColor: .systemBlue,
        action: #selector(didTapStart)
    )

    private lazy var stopButton: UIButton = {
        let button = makeActionButton(
            title: "정지",
            backgroundColor: .systemGray3,
            action: #selector(didTapStop)
        )
        button.isEnabled = false
        return button
    }()

    private lazy var controlStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [startButton, stopButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        return stackView
    }()

    private lazy var routingButton: UIButton = {
        let button = makeActionButton(
            title: "경로 요청 (requestRouting)",
            backgroundColor: .label,
            action: #selector(didTapRequestRouting)
        )
        button.isEnabled = false
        button.alpha = 0.45
        return button
    }()

    private lazy var headerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [controlStackView, routingButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        return stackView
    }()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentStackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = 12
        view.alignment = .fill
        return view
    }()

    private lazy var resultFields: [(title: String, rowView: UIStackView, valueLabel: UILabel)] = [
        makeFieldRow(title: "In/Out State"),
        makeFieldRow(title: "Mobile Time"),
        makeFieldRow(title: "Index"),
        makeFieldRow(title: "Building Name"),
        makeFieldRow(title: "Level Name"),
        makeFieldRow(title: "Position (x, y, heading)"),
        makeFieldRow(title: "Navi Position (x, y, heading)"),
        makeFieldRow(title: "LLH (lat, lon, azimuth)"),
        makeFieldRow(title: "Velocity"),
        makeFieldRow(title: "Is Vehicle"),
        makeFieldRow(title: "Is Indoor"),
        makeFieldRow(title: "Validity Flag"),
        makeFieldRow(title: "Report")
    ]

    private lazy var routingResultField = makeFieldRow(title: "Routing Result (requestRouting)")

    // 샘플 라우팅 좌표 (SAMPLE_ROUTING_RESULT의 B2 경로와 동일한 구간)
    private let routingStart = RoutingStart(level_id: 700, x: 70, y: 10, absolute_heading: 0)
    private let routingEnd = Point(level_id: 700, x: 5, y: 29)

    private var inOutStateLabel: UILabel { resultFields[0].valueLabel }
    private var reportLabel: UILabel { resultFields[resultFields.count - 1].valueLabel }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Jupiter"

        setupLayout()
        setupJupiterService()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            releaseJupiterResources()
        }
    }

    deinit {
        releaseJupiterResources()
    }

    private func setupLayout() {
        view.addSubview(statusLabel)
        view.addSubview(headerStackView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            headerStackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            headerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 48),
            routingButton.heightAnchor.constraint(equalToConstant: 48),

            scrollView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        contentStackView.addArrangedSubview(routingResultField.rowView)
        resultFields.forEach { contentStackView.addArrangedSubview($0.rowView) }
    }

    private func makeActionButton(title: String, backgroundColor: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 14
        button.layer.masksToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeFieldRow(title: String) -> (title: String, rowView: UIStackView, valueLabel: UILabel) {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.text = title

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedSystemFont(ofSize: 18, weight: .semibold)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0
        valueLabel.text = "-"

        let stackView = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.backgroundColor = UIColor.secondarySystemBackground
        stackView.layer.cornerRadius = 14
        stackView.layer.masksToBounds = true

        return (title, stackView, valueLabel)
    }

    private func setupJupiterService() {
        // 매니저 생성과 동시에 초기화가 자동으로 시작된다. 완료(onInitSuccess) 전까지 시작 버튼을 막는다.
        startButton.isEnabled = false
        startButton.alpha = 0.45
        statusLabel.text = "Jupiter 초기화 중... 잠시만 기다려주세요."
        statusLabel.textColor = .secondaryLabel

        let manager = TJJupiterManager(id: jupiterUserId, debugOption: false)
        manager.delegate = self
        jupiterManager = manager
    }

    private func releaseJupiterResources() {
        guard !hasReleasedJupiterResources else { return }
        hasReleasedJupiterResources = true
        jupiterManager?.delegate = nil
        jupiterManager?.stopService(completion: { _, _, _ in })
        jupiterManager = nil
        isServiceRunning = false
    }

    private func updateControlState(isRunning: Bool) {
        isServiceRunning = isRunning
        startButton.isEnabled = !isRunning
        startButton.alpha = isRunning ? 0.45 : 1.0
        stopButton.isEnabled = isRunning
        stopButton.backgroundColor = isRunning ? .systemRed : .systemGray3
    }

    @objc private func didTapStart() {
        guard let manager = jupiterManager else { return }

        statusLabel.text = "Jupiter 시작 중... (mode: \(jupiterMode.rawValue))"
        statusLabel.textColor = .secondaryLabel
        updateControlState(isRunning: true)

        manager.startService()
    }

    @objc private func didTapRequestRouting() {
        guard let manager = jupiterManager else { return }

        routingResultField.valueLabel.text = "경로 요청 중..."
        manager.requestRouting(end: routingEnd) { [weak self] result in
            DispatchQueue.main.async {
                self?.applyRoutingResult(result)
            }
        }
    }

    private func applyRoutingResult(_ result: RoutingResult) {
        if let reason = result.failureReason {
            routingResultField.valueLabel.text = "실패: \(reason.rawValue)"
            return
        }

        guard !result.routes.isEmpty else {
            routingResultField.valueLabel.text = "경로 없음"
            return
        }

        let points = result.routes.enumerated().map { index, route in
            "\(index + 1). [\(route.level_name)] (\(String(format: "%.1f", route.x)), \(String(format: "%.1f", route.y)))"
        }.joined(separator: "\n")
        routingResultField.valueLabel.text = "\(result.routes.count) points\n\(points)"
    }

    @objc private func didTapStop() {
        statusLabel.text = "Jupiter 정지 중..."
        statusLabel.textColor = .secondaryLabel

        jupiterManager?.stopService(completion: { [weak self] isSuccess, msg, result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateControlState(isRunning: false)
                self.statusLabel.text = isSuccess ? "Jupiter 정지됨" : "Jupiter 정지 실패: \(msg)"
                self.statusLabel.textColor = isSuccess ? .secondaryLabel : .systemRed
            }
        })
    }

    private func applyResult(_ result: JupiterResult) {
        let naviPositionText: String
        if let navi = result.navi_pos {
            naviPositionText = format(position: navi)
        } else {
            naviPositionText = "-"
        }

        let llhText: String
        if let llh = result.llh {
            llhText = String(format: "%.6f, %.6f, %.2f", llh.lat, llh.lon, llh.azimuth)
        } else {
            llhText = "-"
        }

        let values = [
            String(result.mobile_time),
            String(result.index),
            result.building_name,
            result.level_name,
            format(position: result.jupiter_pos),
            naviPositionText,
            llhText,
            String(format: "%.3f", result.velocity),
            result.is_vehicle ? "true" : "false",
            result.is_indoor ? "true" : "false",
            String(result.validity_flag)
        ]

        // index 0 = In/Out State, last = Report. 그 사이 필드에 결과를 채운다.
        for (offset, value) in values.enumerated() {
            resultFields[offset + 1].valueLabel.text = value
        }
    }

    private func format(position: Position) -> String {
        return String(format: "%.2f, %.2f, %.2f", position.x, position.y, position.heading)
    }

    private func description(for state: InOutState) -> String {
        switch state {
        case .OUT_TO_IN: return "OUT_TO_IN"
        case .INDOOR: return "INDOOR"
        case .IN_TO_OUT: return "IN_TO_OUT"
        case .OUTDOOR: return "OUTDOOR"
        case .UNKNOWN: return "UNKNOWN"
        @unknown default: return "UNKNOWN"
        }
    }

    // MARK: - TJJupiterManagerDelegate

    func onInitSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterInitErrorCode?) {
        DispatchQueue.main.async {
            if isSuccess {
                self.statusLabel.text = "Jupiter 초기화 완료. 시작 버튼을 눌러주세요."
                self.statusLabel.textColor = .systemGreen
                self.startButton.isEnabled = true
                self.startButton.alpha = 1.0
                self.routingButton.isEnabled = true
                self.routingButton.alpha = 1.0
            } else {
                self.statusLabel.text = "Jupiter 초기화 실패 (code: \(String(describing: code)))"
                self.statusLabel.textColor = .systemRed
                self.startButton.isEnabled = false
                self.startButton.alpha = 0.45
                self.routingButton.isEnabled = false
                self.routingButton.alpha = 0.45
            }
        }
    }

    func onJupiterSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterErrorCode?) {
        DispatchQueue.main.async {
            if isSuccess {
                self.statusLabel.text = "Jupiter 동작 중"
                self.statusLabel.textColor = .systemGreen
            } else {
                self.statusLabel.text = "Jupiter 시작 실패 (code: \(String(describing: code)))"
                self.statusLabel.textColor = .systemRed
                self.updateControlState(isRunning: false)
            }
        }
    }

    func onJupiterReport(_ manager: TJJupiterManager, _ code: JupiterServiceCode, _ msg: String) {
        DispatchQueue.main.async {
            self.reportLabel.text = "\(code) - \(msg)"
        }
    }

    func onJupiterResult(_ manager: TJJupiterManager, _ result: JupiterResult) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Jupiter 결과 수신 중"
            self.statusLabel.textColor = .label
            self.applyResult(result)
        }
    }

    func isJupiterInOutStateChanged(_ manager: TJJupiterManager, _ state: InOutState) {
        DispatchQueue.main.async {
            self.inOutStateLabel.text = self.description(for: state)
        }
    }

    func isUserGuidanceOut() {
        DispatchQueue.main.async {
            self.reportLabel.text = "사용자가 경로를 이탈했습니다."
        }
    }

    func isUserArrived() {
        DispatchQueue.main.async {
            self.statusLabel.text = "목적지에 도착했습니다."
            self.statusLabel.textColor = .systemGreen
        }
    }

    func isNavigationRouteChanged(_ manager: TJJupiterManager, _ routes: [(String, String, Float, Float)]) {
        DispatchQueue.main.async {
            self.reportLabel.text = "경로 갱신됨 (\(routes.count) points)"
        }
    }

    func isNavigationRouteFailed(_ manager: TJJupiterManager, _ reason: NavigationRouteFailureReason) {
        DispatchQueue.main.async {
            self.reportLabel.text = "경로 탐색 실패: \(reason.rawValue)"
        }
    }

    func isWaypointChanged(_ manager: TJJupiterManager, _ waypoints: [[Double]]) {
        DispatchQueue.main.async {
            self.reportLabel.text = "Waypoint 갱신됨 (\(waypoints.count) points)"
        }
    }
}
