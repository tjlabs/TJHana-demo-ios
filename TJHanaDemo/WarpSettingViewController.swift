
import UIKit
import CoreBluetooth
import TJHanaSDK

class WarpSettingViewController: UIViewController {

    private struct MatchedWard {
        let id: Int
        let name: String
        /// nil when the ward is not currently being scanned (only listed in "전체" mode).
        let scannedRSSI: Int?
        let threshold: Int
    }

    private enum DisplayMode: Int {
        case scannedOnly = 0
        case all = 1
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
    private struct ScanSample {
        let rssi: Int
        let time: TimeInterval
    }
    /// Raw scan samples per advertised device name (most recent last).
    private var scanSamplesByName: [String: [ScanSample]] = [:]
    /// Smoothed RSSI of devices seen within `scanWindow`, keyed by advertised
    /// device name. Recomputed on every refresh tick by `aggregateScans()`.
    private var scannedRSSIByName: [String: Int] = [:]
    /// Samples older than this are dropped; a device with no sample in the
    /// window counts as "not currently scanned".
    private let scanWindow: TimeInterval = 3.0
    private let maxSamplesPerDevice = 30

    // MARK: - Table model
    private var sections: [Section] = []
    private var refreshTimer: Timer?
    private var hasReleased = false
    private var displayMode: DisplayMode = .scannedOnly
    private var searchText = ""

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

    private lazy var modeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["스캔된 ward", "전체 ward"])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = DisplayMode.scannedOnly.rawValue
        control.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        return control
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
        setupSearch()
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
        view.addSubview(modeControl)
        view.addSubview(statusLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            modeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupSearch() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "ward 이름 검색"
        searchController.searchBar.autocapitalizationType = .none
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        displayMode = DisplayMode(rawValue: sender.selectedSegmentIndex) ?? .scannedOnly
        rebuildAndReload()
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
        aggregateScans()
        rebuildSections()
        tableView.reloadData()
        updateStatus()
    }

    /// Drops samples older than `scanWindow` and averages the rest, so the
    /// ordering reflects what is being scanned *now* (not a device seen once
    /// minutes ago) and doesn't jump around on every single noisy sample.
    private func aggregateScans() {
        let cutoff = Date().timeIntervalSince1970 - scanWindow
        var aggregated: [String: Int] = [:]
        for (name, samples) in scanSamplesByName {
            let recent = samples.filter { $0.time >= cutoff }
            if recent.isEmpty {
                scanSamplesByName[name] = nil
                continue
            }
            scanSamplesByName[name] = recent
            let mean = Double(recent.reduce(0) { $0 + $1.rssi }) / Double(recent.count)
            aggregated[name] = Int(mean.rounded())
        }
        scannedRSSIByName = aggregated
    }

    /// Groups wards by building → level. In `.scannedOnly` mode only wards whose
    /// name matches a scanned BLE device are kept; in `.all` mode every ward is
    /// listed (scanned ones first) so thresholds can be edited without a scan.
    /// The search text filters by ward name in both modes. Empty levels/buildings
    /// are dropped.
    private func rebuildSections() {
        guard let sectorInfo = sectorInfo else {
            sections = []
            return
        }

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        var newSections: [Section] = []
        for building in sectorInfo.buildings {
            var rows: [RowItem] = []
            for level in building.levels {
                let matchedWards: [RowItem] = level.wards
                    .compactMap { ward -> MatchedWard? in
                        if !query.isEmpty, !ward.name.lowercased().contains(query) { return nil }
                        let scanned = scannedRSSIByName[ward.name]
                        if scanned == nil, displayMode == .scannedOnly { return nil }
                        return MatchedWard(id: ward.id, name: ward.name, scannedRSSI: scanned, threshold: ward.rssi)
                    }
                    // Scanned wards first, strongest signal first (RSSI is negative,
                    // so higher = stronger); unscanned wards after, by name.
                    .sorted { lhs, rhs in
                        switch (lhs.scannedRSSI, rhs.scannedRSSI) {
                        case let (l?, r?):
                            // Equal RSSI → by name, so rows don't swap places every tick.
                            return l != r ? l > r : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                        case (.some, nil): return true
                        case (nil, .some): return false
                        case (nil, nil): return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                        }
                    }
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
        let listedWards: [MatchedWard] = sections.flatMap { section in
            section.rows.compactMap { if case .ward(let ward) = $0 { return ward } else { return nil } }
        }
        let matchedCount = listedWards.filter { $0.scannedRSSI != nil }.count

        if !isWarpInitialized {
            statusLabel.text = "Warp 초기화 중... · 스캔된 기기 \(scannedRSSIByName.count)개"
            statusLabel.textColor = .secondaryLabel
        } else {
            var text = "BLE 스캔 중 · 스캔된 기기 \(scannedRSSIByName.count)개 · 매칭된 ward \(matchedCount)개"
            if displayMode == .all {
                text += " · 전체 \(listedWards.count)개 (미스캔 ward도 수정 가능)"
            }
            statusLabel.text = text
            statusLabel.textColor = matchedCount > 0 ? .systemGreen : .secondaryLabel
        }
    }

    // MARK: - RSSI threshold update

    private typealias TargetOS = WarpRSSIService.OperatingSystem

    private func presentThresholdEditor(for ward: MatchedWard) {
        let scanText = ward.scannedRSSI.map { "스캔 \($0) dBm" } ?? "미스캔"
        // The bundle is downloaded for iOS, so `threshold` is the iOS value;
        // the current Android value is not available in this app.
        let alert = UIAlertController(
            title: ward.name,
            message: "현재 iOS 임계값 \(ward.threshold) dBm · \(scanText)\n새 RSSI 임계값(-127 ~ 0)을 입력하고 적용할 OS를 선택하세요.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .numbersAndPunctuation
            // Prefill with the live scan value when available, otherwise the current threshold.
            textField.text = "\(ward.scannedRSSI ?? ward.threshold)"
            textField.clearButtonMode = .whileEditing
        }

        let options: [(title: String, targets: [TargetOS])] = [
            ("iOS + Android 모두", [.iOS, .android]),
            ("iOS만", [.iOS]),
            ("Android만", [.android])
        ]
        for option in options {
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self, weak alert] _ in
                guard let self = self else { return }
                let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
                guard let rssi = Int(text), (-127...0).contains(rssi) else {
                    self.presentResult(title: "입력 오류", message: "RSSI는 -127 ~ 0 사이의 정수여야 합니다.")
                    return
                }
                self.performUpdate(ward: ward, rssi: rssi, targets: option.targets)
            })
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    private func performUpdate(ward: MatchedWard, rssi: Int, targets: [TargetOS]) {
        guard let baseURL = warpView?.getWarpBaseURL(), !baseURL.isEmpty else {
            presentResult(title: "업데이트 실패", message: "Warp BASE_URL을 가져오지 못했습니다. 초기화 상태를 확인하세요.")
            return
        }

        let targetNames = targets.map { $0.displayName }.joined(separator: ", ")
        statusLabel.text = "\(ward.name) 임계값 업데이트 중... (\(targetNames) · \(rssi) dBm)"
        statusLabel.textColor = .secondaryLabel

        // Fire one PUT per OS and report all results together.
        var results: [TargetOS: Result<Int, WarpRSSIService.ServiceError>] = [:]
        let group = DispatchGroup()
        for os in targets {
            group.enter()
            WarpRSSIService.shared.updateWardRSSI(baseURL: baseURL, wardId: ward.id, rssi: rssi, operatingSystem: os) { result in
                // Completion is delivered on the main thread, so this mutation is serialized.
                results[os] = result
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            let lines: [String] = targets.compactMap { os in
                switch results[os] {
                case .success(let newRSSI)?:
                    return "✓ \(os.displayName): \(newRSSI) dBm 으로 변경"
                case .failure(let error)?:
                    return "✗ \(os.displayName): \(error.localizedDescription)"
                case nil:
                    return nil
                }
            }
            let successCount = results.values.filter { if case .success = $0 { return true } else { return false } }.count
            let title: String
            if successCount == targets.count {
                title = "업데이트 성공"
            } else if successCount == 0 {
                title = "업데이트 실패"
            } else {
                title = "일부 업데이트 실패"
            }
            self.presentResult(title: title, message: "\(ward.name)\n" + lines.joined(separator: "\n"))

            if successCount > 0 {
                // The server bundle's version_id changed; re-download it (forceUpdate)
                // so getWarpSectorInfo() returns the new threshold. onInitSuccess then
                // refreshes sectorInfo and reloads the table.
                self.initializeWarp(forceUpdate: true)
            } else {
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
        // CoreBluetooth reports 127 when the RSSI is unavailable; ignore it,
        // otherwise it would sort above every real (negative) reading.
        let rssi = RSSI.intValue
        guard rssi < 0 else { return }
        var samples = scanSamplesByName[deviceName] ?? []
        samples.append(ScanSample(rssi: rssi, time: Date().timeIntervalSince1970))
        if samples.count > maxSamplesPerDevice {
            samples.removeFirst(samples.count - maxSamplesPerDevice)
        }
        scanSamplesByName[deviceName] = samples
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
            let scanText = ward.scannedRSSI.map { "스캔 \($0)" } ?? "미스캔"
            config.secondaryText = "\(scanText) · iOS 임계 \(ward.threshold) dBm"
            config.textProperties.font = .systemFont(ofSize: 16, weight: .regular)
            config.textProperties.color = ward.scannedRSSI == nil ? .secondaryLabel : .label
            config.secondaryTextProperties.color = ward.scannedRSSI == nil ? .tertiaryLabel : .secondaryLabel
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

// MARK: - UISearchResultsUpdating

extension WarpSettingViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let newText = searchController.searchBar.text ?? ""
        guard newText != searchText else { return }
        searchText = newText
        rebuildAndReload()
    }
}
