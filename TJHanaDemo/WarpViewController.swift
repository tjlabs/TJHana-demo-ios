
import UIKit
import TJHanaSDK

class WarpViewController: UIViewController, TJWarpViewDelegate {
    func onInitSuccess(_ view: TJHanaSDK.TJWarpView, _ isSuccess: Bool, _ code: TJHanaSDK.WarpInitErrorCode?) {
        if isSuccess {
            self.warpView.startService()
            self.warpView.configureFrame(to: self.floatingContainerView, warpImage: UIImage(named: "ic_warp"))
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

    private let warpView = TJWarpView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Warp"
        setupFloatingWarpView()
        initializeWarpView()
    }

    private func setupFloatingWarpView() {
        print("(WarpViewController) setupFloatingWarpView")
        view.addSubview(floatingContainerView)
        view.addSubview(wardListContainerView)

        NSLayoutConstraint.activate([
            floatingContainerView.widthAnchor.constraint(equalToConstant: 80),
            floatingContainerView.heightAnchor.constraint(equalToConstant: 80),
            floatingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),

            wardListContainerView.topAnchor.constraint(equalTo: floatingContainerView.bottomAnchor, constant: 24),
            wardListContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            wardListContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        view.layoutIfNeeded()
    }

    private func initializeWarpView() {
        print("(WarpViewController) initializeWarpView")
        warpView.delegate = self
        warpView.initialize(id: warpUserId, sectorId: 1, forceUpdate: true)
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
}
