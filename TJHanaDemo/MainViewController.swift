import UIKit
import CoreBluetooth
import CoreLocation
import CoreMotion
import TJHanaSDK

class MainViewController: UIViewController, CBCentralManagerDelegate, CLLocationManagerDelegate {
    private enum PermissionFlowState {
        case idle
        case requestingLocation
        case requestingBluetooth
        case requestingMotion
        case ready
    }

    private let accessKey = ""
    private let secretAccessKey = ""
    private var isAuthenticated = false
    
    private let locationManager = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()
    private var bluetoothManager: CBCentralManager?
    private var isShowingPermissionAlert = false
    private var permissionFlowState: PermissionFlowState = .idle

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "인증 필요"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15, weight: .medium)
        return label
    }()

    private lazy var authButton = makeButton(title: "인증", action: #selector(didTapAuth))
    private lazy var warpButton = makeButton(title: "Warp", action: #selector(didTapWarp))
    private lazy var venusButton = makeButton(title: "Venus", action: #selector(didTapVenus))
    private lazy var jupiterButton = makeButton(title: "Jupiter", action: #selector(didTapJupiter))

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [authButton, warpButton, venusButton, jupiterButton])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        return stackView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "HanaDevSDK"
        locationManager.delegate = self
        setupLayout()
        updateServiceButtons(isEnabled: false)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestRuntimePermissionsIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayout() {
        view.addSubview(statusLabel)
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 220),

            authButton.heightAnchor.constraint(equalToConstant: 52),
            warpButton.heightAnchor.constraint(equalToConstant: 52),
            venusButton.heightAnchor.constraint(equalToConstant: 52),
            jupiterButton.heightAnchor.constraint(equalToConstant: 52),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -24)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 14
        button.layer.masksToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateServiceButtons(isEnabled: Bool) {
        isAuthenticated = isEnabled
        configureButtonAppearance(authButton, isEnabled: true, isPrimary: true)
        configureButtonAppearance(warpButton, isEnabled: isEnabled, isPrimary: false)
        configureButtonAppearance(venusButton, isEnabled: isEnabled, isPrimary: false)
        configureButtonAppearance(jupiterButton, isEnabled: isEnabled, isPrimary: false)
        statusLabel.text = isEnabled ? "인증 성공: SDK 기능 사용 가능" : "인증 필요: Warp / Venus / Jupiter 비활성화"
        statusLabel.textColor = isEnabled ? .systemGreen : .secondaryLabel
    }

    private func configureButtonAppearance(_ button: UIButton, isEnabled: Bool, isPrimary: Bool) {
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1.0 : 0.45
        let backgroundColor: UIColor
        if isPrimary {
            backgroundColor = .systemBlue
        } else {
            backgroundColor = isEnabled ? .label : .systemGray3
        }
        button.backgroundColor = backgroundColor
        button.setTitleColor(.white, for: .normal)
    }

    @objc private func didTapAuth() {
        doAuth()
    }

    @objc private func handleDidBecomeActive() {
        requestRuntimePermissionsIfNeeded()
    }

    @objc private func didTapWarp() {
        guard let warpVC = self.storyboard?.instantiateViewController(withIdentifier: "WarpViewController") as? WarpViewController else { return }
        navigationController?.pushViewController(warpVC, animated: true)
    }

    @objc private func didTapVenus() {
        guard let venusVC = self.storyboard?.instantiateViewController(withIdentifier: "VenusViewController") as? VenusViewController else { return }
        navigationController?.pushViewController(venusVC, animated: true)
    }

    @objc private func didTapJupiter() {
        guard let jupiterVC = self.storyboard?.instantiateViewController(withIdentifier: "JupiterViewController") as? JupiterViewController else { return }
        navigationController?.pushViewController(jupiterVC, animated: true)
    }

    private func doAuth() {
        guard !accessKey.isEmpty, !secretAccessKey.isEmpty else {
            updateServiceButtons(isEnabled: false)
            statusLabel.text = "인증 키를 입력해야 합니다"
            statusLabel.textColor = .systemRed
            return
        }

        statusLabel.text = "인증 진행 중..."
        statusLabel.textColor = .secondaryLabel
        authButton.isEnabled = false
        authButton.backgroundColor = .systemGray
        
        TJHanaAuth.shared.auth(accessKey: accessKey, secretAccessKey: secretAccessKey) { [weak self] code, isSuccess in
            guard let self = self else { return }
            self.configureButtonAppearance(self.authButton, isEnabled: true, isPrimary: true)

            if isSuccess {
                self.updateServiceButtons(isEnabled: true)
            } else {
                self.updateServiceButtons(isEnabled: false)
                self.statusLabel.text = "인증 실패 (code: \(code))"
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    private func requestRuntimePermissionsIfNeeded() {
        continuePermissionPipeline()
    }

    private func continuePermissionPipeline() {
        guard isViewLoaded, view.window != nil else {
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionFlowState = .requestingLocation
            locationManager.requestWhenInUseAuthorization()
            return
        case .restricted, .denied:
            permissionFlowState = .idle
            presentPermissionSettingsAlert(
                title: "위치 권한 필요",
                message: "앱 사용을 위해 위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요."
            )
            return
        case .authorizedAlways, .authorizedWhenInUse:
            permissionFlowState = .requestingBluetooth
        @unknown default:
            permissionFlowState = .requestingBluetooth
        }

        if #available(iOS 13.1, *) {
            switch CBManager.authorization {
            case .notDetermined:
                permissionFlowState = .requestingBluetooth
                createBluetoothManagerIfNeeded()
                return
            case .restricted, .denied:
                permissionFlowState = .idle
                presentPermissionSettingsAlert(
                    title: "블루투스 권한 필요",
                    message: "앱 사용을 위해 블루투스 권한이 필요합니다. 설정에서 블루투스 권한을 허용해주세요."
                )
                return
            case .allowedAlways:
                createBluetoothManagerIfNeeded()
            @unknown default:
                createBluetoothManagerIfNeeded()
            }
        } else {
            createBluetoothManagerIfNeeded()
        }

        if #available(iOS 11.0, *) {
            switch CMMotionActivityManager.authorizationStatus() {
            case .notDetermined:
                requestMotionAuthorizationIfNeeded()
                return
            case .restricted, .denied:
                permissionFlowState = .idle
                presentPermissionSettingsAlert(
                    title: "모션 권한 필요",
                    message: "앱 사용을 위해 모션 및 피트니스 권한이 필요합니다. 설정에서 모션 권한을 허용해주세요."
                )
                return
            case .authorized:
                permissionFlowState = .ready
            @unknown default:
                permissionFlowState = .ready
            }
        } else {
            permissionFlowState = .ready
        }

        permissionFlowState = .ready
    }

    private func createBluetoothManagerIfNeeded() {
        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(
                delegate: self,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: true]
            )
        }
    }

    private func requestMotionAuthorizationIfNeeded() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            permissionFlowState = .ready
            return
        }

        permissionFlowState = .requestingMotion
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-60)
        motionActivityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { [weak self] _, _ in
            self?.continuePermissionPipeline()
        }
    }

    private func presentPermissionSettingsAlert(title: String, message: String) {
        guard !isShowingPermissionAlert, presentedViewController == nil else {
            return
        }

        isShowingPermissionAlert = true
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            self?.isShowingPermissionAlert = false
        })
        alert.addAction(UIAlertAction(title: "설정", style: .default) { [weak self] _ in
            self?.isShowingPermissionAlert = false
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuePermissionPipeline()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 13.1, *) {
            switch CBManager.authorization {
            case .notDetermined:
                return
            case .restricted, .denied:
                permissionFlowState = .idle
                presentPermissionSettingsAlert(
                    title: "블루투스 권한 필요",
                    message: "앱 사용을 위해 블루투스 권한이 필요합니다. 설정에서 블루투스 권한을 허용해주세요."
                )
                return
            case .allowedAlways:
                permissionFlowState = .ready
            @unknown default:
                permissionFlowState = .ready
            }
        }

        if central.state == .unauthorized {
            permissionFlowState = .idle
            presentPermissionSettingsAlert(
                title: "블루투스 권한 필요",
                message: "앱 사용을 위해 블루투스 권한이 필요합니다. 설정에서 블루투스 권한을 허용해주세요."
            )
            return
        }

        if permissionFlowState == .requestingBluetooth {
            continuePermissionPipeline()
        }
    }
}
