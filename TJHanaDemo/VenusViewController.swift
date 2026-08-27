
import UIKit
import TJHanaSDK

final class VenusViewController: UIViewController, TJVenuseManagerDelegate {
    private let venusUserId = "hana-example-user"
    private var venusServiceManager: TJVenusManager?
    private var hasReleasedVenusResources = false

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Venus 초기화 중..."
        return label
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
        makeFieldRow(title: "Mobile Time"),
        makeFieldRow(title: "Building ID"),
        makeFieldRow(title: "Building Name"),
        makeFieldRow(title: "Level ID"),
        makeFieldRow(title: "Level Name"),
        makeFieldRow(title: "X"),
        makeFieldRow(title: "Y")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Venus"

        setupLayout()
        setupVenusService()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            releaseVenusResources()
        }
    }

    deinit {
        releaseVenusResources()
    }

    private func setupLayout() {
        view.addSubview(statusLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        resultFields.forEach { contentStackView.addArrangedSubview($0.rowView) }
    }

    private func makeFieldRow(title: String) -> (String, UIStackView, UILabel) {
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

    private func setupVenusService() {
        let manager = TJVenusManager(id: venusUserId, forceUpdate: true)
        manager.delegate = self
        venusServiceManager = manager
    }

    private func releaseVenusResources() {
        guard !hasReleasedVenusResources else { return }
        hasReleasedVenusResources = true
        venusServiceManager?.delegate = nil
        venusServiceManager?.stopService()
        venusServiceManager = nil
    }

    private func applyResult(_ result: VenusResult) {
        let values = [
            String(result.mobile_time),
            String(result.building_id),
            result.building_name,
            String(result.level_id),
            result.level_name,
            String(result.x),
            String(result.y)
        ]

        for (index, value) in values.enumerated() {
            resultFields[index].valueLabel.text = value
        }
    }

    func onInitSuccess(_ manager: TJHanaSDK.TJVenusManager, _ isSuccess: Bool, _ code: TJHanaSDK.VenusInitErrorCode?) {
        DispatchQueue.main.async {
            if isSuccess {
                self.statusLabel.text = "Venus 초기화 성공. 스캔 시작 중..."
                self.statusLabel.textColor = .systemGreen
                manager.startService()
            } else {
                self.statusLabel.text = "Venus 초기화 실패 (code: \(String(describing: code)))"
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    func onVenusSuccess(_ manager: TJHanaSDK.TJVenusManager, _ isSuccess: Bool, _ code: TJHanaSDK.VenusErrorCode?) {
        DispatchQueue.main.async {
            if isSuccess {
                self.statusLabel.text = "Venus 스캔 중"
                self.statusLabel.textColor = .systemGreen
            } else {
                self.statusLabel.text = "Venus 시작 실패 (code: \(String(describing: code)))"
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    func onVenusResult(_ manager: TJHanaSDK.TJVenusManager, _ result: TJHanaSDK.VenusResult) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Venus 결과 수신"
            self.statusLabel.textColor = .label
            self.applyResult(result)
        }
    }
}
