
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
        let wrapped = result.toWrap()
        DispatchQueue.main.async { [weak self] in
            self?.latestResult = wrapped
        }
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
    private var mockTimer: DispatchSourceTimer?
    private var mockResults: [JupiterResult] = []
    private var mockIndex: Int = 0

    private var resultIntervalMs: Int = 1000
    private var resultTimer: DispatchSourceTimer?
    private var latestResult: JupiterResult?

    public weak var delegate: TJJupiterManagerDelegate?

    var serviceManager: JupiterServiceManager?

    public init(id: String, sectorId: Int = HANA_SECTOR_ID, debugOption: Bool = false) {
        self.id = id
        self.sectorId = sectorId
        
//        self.serviceManager = JupiterServiceManager(id: id, region: HanaRegion.KOREA.rawValue, sectorId: sectorId, debugOption: debugOption, onPremiseBaseURL: ON_PREMISE_BASE_URL)
//        self.serviceManager?.delegate = self
        // delegate는 생성 직후 할당되므로, 현재 실행 흐름이 끝난 뒤(비동기) 초기화 성공을 전달한다.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.onInitSuccess(self, true, nil)
        }
    }
    
    deinit {
        serviceManager?.delegate = nil

        stopMockTimer()
        stopResultTimer()
        serviceManager?.stopService(completion: {_, _, _ in})
        serviceManager = nil
    }

    /// delegate(onJupiterResult)로 위치 결과를 전달하는 주기를 밀리초 단위로 설정한다.
    /// init 이후 언제든 호출 가능하며, 서비스가 이미 실행 중이면 즉시 새 주기로 재시작한다.
    public func setResultInterval(milliseconds: Int) {
        resultIntervalMs = max(1, milliseconds)
        if mockTimer != nil {
            startMockService()
        }
    }

    public func startService(resultIntervalMs: Int = 1000) {
        self.resultIntervalMs = max(1, resultIntervalMs)
        // 항상 DR(MODE_VEHICLE)로 강제 시작한다.
//        serviceManager?.startService(mode: UserMode.MODE_VEHICLE.toJupiter())
        // startService 성공 시 delegate로 mock 결과를 전달한다.
        startMockService()
        delegate?.onJupiterSuccess(self, true, nil)
    }

    public func stopService(completion: @escaping (Bool, String, JupiterServiceResult) -> Void) {
        stopMockTimer()
        stopResultTimer()
//        serviceManager?.stopService(completion: completion)
    }

    // MARK: - Result delivery timer
    // NavigationManager가 push한 최신 결과를 설정된 주기(resultIntervalMs)로 delegate에 전달한다.
    // 현재 startService는 mock 결과만 전달하므로 사용하지 않지만, 실제 결과 전달로 되돌릴 때 다시 사용한다.
    private func startResultTimer() {
        stopResultTimer()

        latestResult = nil

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(resultIntervalMs))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            // 같은 결과라도 설정된 주기마다 무조건 전달한다(아직 결과가 없으면 스킵).
            guard let result = self.latestResult else { return }
            self.delegate?.onJupiterResult(self, result)
        }
        resultTimer = timer
        timer.resume()
    }

    private func stopResultTimer() {
        resultTimer?.cancel()
        resultTimer = nil
    }

    // MARK: - Mock
    private func startMockService() {
        stopMockTimer()
        mockResults = SAMPLE_MOCK_JUPITER_RESULTS
        mockIndex = 0
        guard !mockResults.isEmpty else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(resultIntervalMs))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard self.mockIndex < self.mockResults.count else {
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
    
    public func requestRouting(end: Point,
                               waypoints: [Point] = [],
                               completion: @escaping (RoutingResult) -> Void) {
        completion(SAMPLE_ROUTING_RESULT)
        
//        guard let latestResult = self.latestResult else {
//            completion(RoutingResult(routes: [], failureReason: .INTERNAL_ERROR))
//            return
//        }
//        guard let levelId = serviceManager?.getLevelId(sectorId: sectorId, buildingName: latestResult.building_name, levelName: latestResult.level_name) else {
//            completion(RoutingResult(routes: [], failureReason: .INTERNAL_ERROR))
//            return
//        }
//        guard let scaleOffset = serviceManager?.getScaleOffset(sectorId: sectorId, buildingName: latestResult.building_name, levelName: latestResult.level_name) else {
//            completion(RoutingResult(routes: [], failureReason: .SCALE_OFFSET_ERROR))
//            return
//        }
//        if scaleOffset.count < 4 {
//            completion(RoutingResult(routes: [], failureReason: .SCALE_OFFSET_ERROR))
//            return
//        }
//        
//        let scaleX = scaleOffset[0]
//        let scaleY = scaleOffset[1]
//        let offsetX = scaleOffset[2]
//        let offsetY = scaleOffset[3]
//
//        let origin = RoutingStart(level_id: levelId, x: Int(latestResult.jupiter_pos.x), y: Int(latestResult.jupiter_pos.y), absolute_heading: Int(latestResult.jupiter_pos.heading))
//        
//        let destX = Float(end.x)*scaleX + offsetX
//        let destY = Float(end.y)*scaleY + offsetY
//        let destination = Point(level_id: end.level_id, x: Int(destX), y: Int(destY))
//        
//        serviceManager?.requestRouting(start: origin.toJupiter(),
//                                       end: destination.toJupiter(),
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
