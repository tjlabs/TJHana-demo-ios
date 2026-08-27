
import Foundation
import TJLabsJupiter
import TJLabsHana
import TJLabsResource
    
public class TJJupiterManager: NavigationManagerDelegate {
    
    public func onInitSuccess(_ isSuccess: Bool, _ code: TJLabsJupiter.InitErrorCode?, _ result: TJLabsJupiter.JupiterServiceResult) {
        delegate?.onInitSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onJupiterSuccess(_ isSuccess: Bool, _ code: TJLabsJupiter.JupiterErrorCode?, _ result: TJLabsJupiter.JupiterServiceResult) {
        delegate?.onJupiterSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onJupiterResult(_ result: TJLabsJupiter.JupiterResult) {
        if mockMode {
            // mockMode에서는 실제 측위 결과를 버리고, mock 타이머가 대신 결과를 전달한다.
            return
        }
        delegate?.onJupiterResult(self, result.toWrap())
    }
    
    public func onJupiterReport(_ code: TJLabsJupiter.JupiterServiceCode, _ msg: String) {
        if code.rawValue < 8 {
            delegate?.onJupiterReport(self, code.toWrap(), msg)
        }
    }
    
    public func isJupiterInOutStateChanged(_ state: TJLabsJupiter.InOutState) {
        delegate?.isJupiterInOutStateChanged(self, state.toWrap())
    }
    
    public func isUserGuidanceOut() {
        delegate?.isUserGuidanceOut()
    }
    
    public func isUserArrived() {
        delegate?.isUserArrived()
    }
    
    public func isNavigationRouteChanged(_ routes: [(String, String, Float, Float)]) {
        delegate?.isNavigationRouteChanged(self, routes)
    }
    
    public func isNavigationRouteFailed(_ reason: TJLabsJupiter.NavigationRouteFailureReason) {
        delegate?.isNavigationRouteFailed(self, reason.toWrap())
    }
    
    public func isWaypointChanged(_ waypoints: [[Double]]) {
        delegate?.isWaypointChanged(self, waypoints)
    }
    
    private var region: String = ""
    private var id: String = ""
    private var sectorId: Int = 0
    private var mockMode: Bool = false
    private var mockTimer: DispatchSourceTimer?
    private var mockResults: [JupiterResult] = []
    private var mockIndex: Int = 0
    public weak var delegate: TJJupiterManagerDelegate?

    var serviceManager: JupiterServiceManager?

    public init(id: String, sectorId: Int = HANA_SECTOR_ID, debugOption: Bool = false) {
        self.id = id
        self.sectorId = sectorId
        
        self.serviceManager = JupiterServiceManager(id: id, region: HanaRegion.KOREA.rawValue, sectorId: sectorId, debugOption: debugOption, onPremiseBaseURL: ON_PREMISE_BASE_URL)
        self.serviceManager?.delegate = self
    }
    
    deinit {
        serviceManager?.delegate = nil

        stopMockTimer()
        serviceManager?.stopService(completion: {_, _, _ in})
        serviceManager = nil
    }

    public func setMockMode(flag: Bool) {
        self.mockMode = flag
    }

    public func startService() {
        // 항상 DR(MODE_VEHICLE)로 강제 시작한다.
        serviceManager?.startService(mode: UserMode.MODE_VEHICLE.toJupiter())
        if mockMode {
            startMockService()
        }
    }

    public func stopService(completion: @escaping (Bool, String, JupiterServiceResult) -> Void) {
        stopMockTimer()
        serviceManager?.stopService(completion: completion)
    }

    // MARK: - Mock
    private func startMockService() {
        stopMockTimer()
        mockResults = SAMPLE_MOCK_JUPITER_RESULTS
        mockIndex = 0
        guard !mockResults.isEmpty else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: MOCK_JUPITER_INTERVAL)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard self.mockIndex < self.mockResults.count else {
                // 경로 끝에 도달하면 타이머 정지
                self.stopMockTimer()
                return
            }
            var result = self.mockResults[self.mockIndex]
            result.mobile_time = Int(Date().timeIntervalSince1970 * 1000)
            self.mockIndex += 1
            self.delegate?.onJupiterResult(self, result)
        }
        mockTimer = timer
        timer.resume()
    }

    private func stopMockTimer() {
        mockTimer?.cancel()
        mockTimer = nil
    }
    
    public func setNavigationDestination(dest: Point) {
        serviceManager?.setNaviDestination(dest: dest.toJupiter(), isVehicle: true)
    }
    
    public func requestRouting(start: RoutingStart,
                               end: Point,
                               waypoints: [Point] = [],
                               completion: @escaping (RoutingResult) -> Void) {
        // TODO: temporary — always return SAMPLE_ROUTING_RESULT. Restore the block below to use real routing.
        completion(SAMPLE_ROUTING_RESULT)
//        serviceManager?.requestRouting(start: start.toJupiter(),
//                                       end: end.toJupiter(),
//                                       waypoints: waypoints.map{$0.toJupiter()}, isVehicle: true, completion: { _, navigationLevelRoutes, navigationFailureReason in
//            let routes = navigationLevelRoutes.flatMap { levelRoute -> [RoutingRoute] in
//                let levelName = TJLabsResourceManager.shared.getLevelName(levelId: levelRoute.levelId) ?? ""
//                return levelRoute.points.map { point in
//                    RoutingRoute(level_id: levelRoute.levelId, level_name: levelName, x: point.x, y: point.y)
//                }
//            }
//            completion(RoutingResult(routes: routes, failureReason: navigationFailureReason?.toWrap()))
//        })
    }
}
