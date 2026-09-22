
import UIKit
import CoreBluetooth
import TJHanaSDK

class WarpSettingViewController: UIViewController {

    private struct MatchedWard {
        let id: Int
        let name: String
        let scannedRSSI: Int
        let threshold: Int
    }

    private enum RowItem {
        case level(name: String)
        case ward(MatchedWard)
    }

    private struct Section {
        let building: String
        let rows: [RowItem]
    }

    // MARK: - Warp
    private let warpUserId = "hana-example-user"
    private var warpView: TJWarpView? = TJWarpView()
    private var sectorInfo: WarpSectorInfo?
    private var isWarpInitialized = false

    // MARK: - BLE
    private var centralManager: CBCentralManager?
    /// Latest scanned RSSI keyed by advertised device name.
    private var scannedRSSIByName: [String: Int] = [:]

    // MARK: - Table model
    private var sections: [Section] = []
    private var refreshTimer: Timer?
    private var hasReleased = false

    private let levelCellId = "LevelCell"
    private let wardCellId = "WardCell"

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Warp 초기화 중..."
        return label
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "WarpSetting"

        setupLayout()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: levelCellId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: wardCellId)

        centralManager = CBCentralManager(delegate: self, queue: nil)
        initializeWarp()
        startRefreshTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            release()
        }
    }

    deinit {
        release()
    }

    private func setupLayout() {
        view.addSubview(statusLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Warp

    // forceUpdate: true re-downloads the bundle so a server-side RSSI change
    // (new version_id) is reflected without restarting the app.
    private func initializeWarp(forceUpdate: Bool = true) {
        warpView?.delegate = self
        warpView?.initialize(id: warpUserId, forceUpdate: forceUpdate)
    }

    // MARK: - Refresh

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.rebuildAndReload()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func rebuildAndReload() {
        rebuildSections()
        tableView.reloadData()
        updateStatus()
    }

    /// Keeps only wards whose name matches a scanned BLE device, grouped by
    /// building → level. Levels/buildings with no matches are dropped.
    private func rebuildSections() {
        guard let sectorInfo = sectorInfo else {
            sections = []
            return
        }

        var newSections: [Section] = []
        for building in sectorInfo.buildings {
            var rows: [RowItem] = []
            for level in building.levels {
                let matchedWards: [RowItem] = level.wards
                    .compactMap { ward -> MatchedWard? in
                        guard let scanned = scannedRSSIByName[ward.name] else { return nil }
                        return MatchedWard(id: ward.id, name: ward.name, scannedRSSI: scanned, threshold: ward.rssi)
                    }
                    // Strongest signal first (RSSI is negative, so higher = stronger).
                    .sorted { $0.scannedRSSI > $1.scannedRSSI }
                    .map { RowItem.ward($0) }
                if !matchedWards.isEmpty {
                    rows.append(.level(name: level.name))
                    rows.append(contentsOf: matchedWards)
                }
            }
            if !rows.isEmpty {
                newSections.append(Section(building: building.name, rows: rows))
            }
        }
        sections = newSections
    }

    private func updateStatus() {
        let matchedCount = sections.reduce(0) { partial, section in
            partial + section.rows.filter { if case .ward = $0 { return true } else { return false } }.count
        }

        if !isWarpInitialized {
            statusLabel.text = "Warp 초기화 중... · 스캔된 기기 \(scannedRSSIByName.count)개"
            statusLabel.textColor = .secondaryLabel
        } else {
            statusLabel.text = "BLE 스캔 중 · 스캔된 기기 \(scannedRSSIByName.count)개 · 매칭된 ward \(matchedCount)개"
            statusLabel.textColor = matchedCount > 0 ? .systemGreen : .secondaryLabel
        }
    }

    // MARK: - RSSI threshold update

    private func presentThresholdEditor(for ward: MatchedWard) {
        let alert = UIAlertController(
            title: ward.name,
            message: "현재 임계값 \(ward.threshold) dBm · 스캔 \(ward.scannedRSSI) dBm\n새 RSSI 임계값(-127 ~ 0)을 입력하세요.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .numbersAndPunctuation
            textField.text = "\(ward.scannedRSSI)"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "업데이트", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard let rssi = Int(text), (-127...0).contains(rssi) else {
                self.presentResult(title: "입력 오류", message: "RSSI는 -127 ~ 0 사이의 정수여야 합니다.")
                return
            }
            self.performUpdate(ward: ward, rssi: rssi)
        })
        present(alert, animated: true)
    }

    private func performUpdate(ward: MatchedWard, rssi: Int) {
        guard let baseURL = warpView?.getWarpBaseURL(), !baseURL.isEmpty else {
            presentResult(title: "업데이트 실패", message: "Warp BASE_URL을 가져오지 못했습니다. 초기화 상태를 확인하세요.")
            return
        }

        statusLabel.text = "\(ward.name) 임계값 업데이트 중... (\(rssi) dBm)"
        statusLabel.textColor = .secondaryLabel

        WarpRSSIService.shared.updateWardRSSI(baseURL: baseURL, wardId: ward.id, rssi: rssi) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let newRSSI):
                self.presentResult(
                    title: "업데이트 성공",
                    message: "\(ward.name)\niOS 임계값이 \(newRSSI) dBm 으로 변경되었습니다."
                )
                // The server bundle's version_id changed; re-download it (forceUpdate)
                // so getWarpSectorInfo() returns the new threshold. onInitSuccess then
                // refreshes sectorInfo and reloads the table.
                self.initializeWarp(forceUpdate: true)
            case .failure(let error):
                self.presentResult(
                    title: "업데이트 실패",
                    message: error.localizedDescription
                )
                self.updateStatus()
            }
        }
    }

    private func presentResult(title: String, message: String) {
        // Callers may fire this synchronously from inside the editor alert's
        // action handler (validation errors) while that alert is still
        // dismissing. Presenting then is silently dropped, so wait until no
        // view controller is being presented before showing the result.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.viewIfLoaded?.window != nil else { return }
            if self.presentedViewController != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.presentResult(title: title, message: message)
                }
                return
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Teardown

    private func release() {
        guard !hasReleased else { return }
        hasReleased = true

        refreshTimer?.invalidate()
        refreshTimer = nil

        centralManager?.stopScan()
        centralManager?.delegate = nil
        centralManager = nil

        warpView?.delegate = nil
        warpView?.stopService()
        warpView = nil
    }
}

// MARK: - TJWarpViewDelegate

extension WarpSettingViewController: TJWarpViewDelegate {
    func onInitSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpInitErrorCode?) {
        if isSuccess {
            isWarpInitialized = true
            sectorInfo = view.getWarpSectorInfo()
            rebuildAndReload()
        } else {
            statusLabel.text = "Warp 초기화 실패 (code: \(String(describing: code)))"
            statusLabel.textColor = .systemRed
        }
    }

    func onWarpSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpErrorCode?) {}

    func onClick(_ view: TJWarpView, warpWards: [WarpWard]) {}

    func onWarpSelectionChanged(_ view: TJWarpView, warpWards: [WarpWard]) {}
}

// MARK: - CBCentralManagerDelegate

extension WarpSettingViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        default:
            central.stopScan()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let deviceName = (advertisedName ?? peripheral.name)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !deviceName.isEmpty else {
            return
        }
        scannedRSSIByName[deviceName] = RSSI.intValue
    }
}

// MARK: - UITableViewDataSource / Delegate

extension WarpSettingViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].building
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case .level(let name):
            let cell = tableView.dequeueReusableCell(withIdentifier: levelCellId, for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = name
            config.textProperties.font = .systemFont(ofSize: 13, weight: .semibold)
            config.textProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.backgroundColor = .secondarySystemBackground
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell

        case .ward(let ward):
            let cell = tableView.dequeueReusableCell(withIdentifier: wardCellId, for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = ward.name
            config.secondaryText = "스캔 \(ward.scannedRSSI) · 임계 \(ward.threshold) dBm"
            config.textProperties.font = .systemFont(ofSize: 16, weight: .regular)
            config.secondaryTextProperties.color = .secondaryLabel
            config.prefersSideBySideTextAndSecondaryText = true
            config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 36, bottom: 10, trailing: 16)
            cell.contentConfiguration = config
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard case .ward(let ward) = sections[indexPath.section].rows[indexPath.row] else { return }
        presentThresholdEditor(for: ward)
    }
}
