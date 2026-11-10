
import Foundation
import TJLabsJupiter
import TJLabsHana
import TJLabsResource
    
private let VEHICLE_ROUTE_FOLLOWING_DISTANCE: Float = 50

public class TJJupiterManager: NavigationManagerDelegate {
    
    public func onInitSuccess(_ isSuccess: Bool, _ code: TJLabsJupiter.InitErrorCode?, _ result: TJLabsJupiter.JupiterServiceResult) {
        // Jupiter initialize가 경로 추종 거리를 기본값으로 되돌리므로, 초기화 성공 이후에 설정한다.
        if isSuccess {
            serviceManager?.setVehicleRouteFollowingDistance(distance: VEHICLE_ROUTE_FOLLOWING_DISTANCE)
        }
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
        // routes = (building, level, x, y) 내부 좌표이므로 각 점이 속한 층의 scale/offset으로 고객사 좌표로 변환한다.
        // scale/offset을 구할 수 없는 점은 변환 없이 그대로 전달한다.
        let converted = routes.map { route -> (String, String, Float, Float) in
            guard let scaleOffset = getScaleOffset(buildingName: route.0, levelName: route.1) else { return route }
            let pos = scaleOffset.toCustomer(x: route.2, y: route.3)
            return (route.0, route.1, pos.x, pos.y)
        }
        delegate?.isNavigationRouteChanged(self, converted)
    }
    
    public func isNavigationRouteFailed(_ reason: TJLabsJupiter.NavigationRouteFailureReason) {
        delegate?.isNavigationRouteFailed(self, reason.toWrap())
    }
    
    public func isWaypointChanged(_ waypoints: [[Double]]) {
        // waypoints = [[x, y]] 내부 좌표로 층 정보가 없으므로 현재 위치 층의 scale/offset으로 고객사 좌표로 변환한다.
        // latestResult는 main에서 갱신되므로 main에서 읽고 전달한다.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let latestResult = self.latestResult,
                  let scaleOffset = self.getScaleOffset(buildingName: latestResult.building_name, levelName: latestResult.level_name) else {
                print("(TJJupiterManager) isWaypointChanged : scaleOffset= nil -> no conversion")
                self.delegate?.isWaypointChanged(self, waypoints)
                return
            }
            let converted = waypoints.map { waypoint -> [Double] in
                guard waypoint.count >= 2 else { return waypoint }
                let pos = scaleOffset.toCustomer(x: Float(waypoint[0]), y: Float(waypoint[1]))
                return [Double(pos.x), Double(pos.y)] + waypoint.dropFirst(2)
            }
            self.delegate?.isWaypointChanged(self, converted)
        }
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
        
        self.serviceManager = JupiterServiceManager(id: id, region: HanaRegion.KOREA.rawValue, sectorId: sectorId, debugOption: debugOption, onPremiseBaseURL: ON_PREMISE_BASE_URL)
        self.serviceManager?.delegate = self

        // 고객사 delegate는 생성 직후 할당되므로, 현재 실행 흐름이 끝난 뒤(비동기) 초기화를 시작한다.
        // (NOT_AUTHORIZED, INVALID_ID 등 init 실패는 동기로 통지되므로 delegate 연결 전에 호출하면 누락된다.)
        DispatchQueue.main.async { [weak self] in
            self?.serviceManager?.initialize()
        }
    }
    
    deinit {
        serviceManager?.delegate = nil

//        stopMockTimer()
        stopResultTimer()
        serviceManager?.stopService(completion: {_, _, _ in})
        serviceManager = nil
    }

    /// delegate(onJupiterResult)로 위치 결과를 전달하는 주기를 밀리초 단위로 설정한다.
    /// init 이후 언제든 호출 가능하며, 서비스가 이미 실행 중이면 즉시 새 주기로 재시작한다.
    public func setResultInterval(milliseconds: Int) {
        resultIntervalMs = max(1, milliseconds)
        // 실행 중인 타이머는 latestResult를 유지한 채 주기만 재설정한다.
        resultTimer?.schedule(deadline: .now(), repeating: .milliseconds(resultIntervalMs))
//        if mockTimer != nil {
//            startMockService()
//        }
    }

    public func startService(resultIntervalMs: Int = 1000) {
        self.resultIntervalMs = max(1, resultIntervalMs)
        startResultTimer()
        // 항상 DR(MODE_VEHICLE)로 강제 시작한다.
        serviceManager?.startService(mode: UserMode.MODE_VEHICLE.toJupiter())
        
        // startService 성공 시 delegate로 mock 결과를 전달한다.
//        startMockService()
//        delegate?.onJupiterSuccess(self, true, nil)
    }

    public func stopService(completion: @escaping (Bool, String) -> Void) {
//        stopMockTimer()
        stopResultTimer()
        guard let serviceManager = serviceManager else {
            completion(false, "serviceManager is not initialized")
            return
        }
        serviceManager.stopService(completion: { isSuccess, msg, _ in
            completion(isSuccess, msg)
        })
    }
    
    public func setReplayMode(flag: Bool, rfdFileName: String, uvdFileName: String, eventFileName: String) {
        serviceManager?.setReplayMode(flag: flag, rfdFileName: rfdFileName, uvdFileName: uvdFileName, eventFileName: eventFileName)
    }

    // MARK: - Result delivery timer
    // NavigationManager가 push한 최신 결과를 설정된 주기(resultIntervalMs)로 delegate에 전달한다.
    private func startResultTimer() {
        stopResultTimer()

        latestResult = nil

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(resultIntervalMs))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            // 같은 결과라도 설정된 주기마다 무조건 전달한다(아직 결과가 없으면 스킵).
            // latestResult는 routing origin으로 쓰이므로 내부 좌표로 유지하고, 전달 시점에만 고객사 좌표로 변환한다.
            guard let result = self.latestResult else { return }
            self.delegate?.onJupiterResult(self, self.toCustomerResult(result))
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
        // dest는 고객사 좌표로 입력받으므로 해당 층의 scale/offset으로 내부 좌표로 변환한다.
        // levelId로 건물을 조회하는 API가 없어 현재 위치의 건물을 사용한다.
        guard let serviceManager else { return }
        guard let latestResult = self.latestResult,
              let levelName = serviceManager.getLevelName(levelId: dest.level_id),
              let scaleOffset = getScaleOffset(buildingName: latestResult.building_name, levelName: levelName) else {
            // 변환할 수 없으면 잘못된 목적지가 설정되지 않도록 설정하지 않는다.
            print("(TJJupiterManager) setNavigationDestination : fail=\(NavigationRouteFailureReason.SCALE_OFFSET_ERROR.rawValue) dest= [levelId:\(dest.level_id), x:\(dest.x), y:\(dest.y)]")
            return
        }
        let internalDest = scaleOffset.toInternal(dest)
        print("(TJJupiterManager) setNavigationDestination : dest= [levelId:\(dest.level_id), x:\(dest.x), y:\(dest.y)] -> internal= [x:\(internalDest.x), y:\(internalDest.y)]")
        serviceManager.setNaviDestination(dest: internalDest.toJupiter(), isVehicle: true)
    }
    
    
    public func requestRouting(end: Point,
                               waypoints: [Point] = [],
                               completion: @escaping (RoutingResult) -> Void) {
        // 서버 이벤트 input 에는 이 함수의 입력값 전부(고객사 좌표 그대로)를 담는다.
        let eventInput: [String: JSONValue] = [
            "end": end.toEventJSON(),
            "waypoints": .array(waypoints.map { $0.toEventJSON() }),
        ]
        guard let serviceManager else {
            // Jupiter 인스턴스가 없어 서버 이벤트를 보낼 수 없으므로 로그만 남긴다.
            print("(TJJupiterManager) requestRouting : fail=\(NavigationRouteFailureReason.NOT_READY.rawValue) input=\(eventInput)")
            completion(RoutingResult(routes: [], failureReason: .NOT_READY))
            return
        }
        guard let latestResult = self.latestResult else {
            serviceManager.reportRoutingPreconditionFailure(source: "TJHanaSDK", reason: NavigationRouteFailureReason.NO_CURRENT_POSITION.rawValue,
                                                            input: eventInput, detail: ["sector_id": .int(sectorId)])
            completion(RoutingResult(routes: [], failureReason: .NO_CURRENT_POSITION))
            return
        }
        let positionDetail: [String: JSONValue] = [
            "sector_id": .int(sectorId),
            "building_name": .string(latestResult.building_name),
            "level_name": .string(latestResult.level_name),
        ]
        guard let levelId = serviceManager.getLevelId(sectorId: sectorId, buildingName: latestResult.building_name, levelName: latestResult.level_name) else {
            serviceManager.reportRoutingPreconditionFailure(source: "TJHanaSDK", reason: NavigationRouteFailureReason.LEVEL_NOT_FOUND.rawValue,
                                                            input: eventInput, detail: positionDetail)
            completion(RoutingResult(routes: [], failureReason: .LEVEL_NOT_FOUND))
            return
        }
        guard let scaleOffset = getScaleOffset(buildingName: latestResult.building_name, levelName: latestResult.level_name) else {
            serviceManager.reportRoutingPreconditionFailure(source: "TJHanaSDK", reason: NavigationRouteFailureReason.SCALE_OFFSET_ERROR.rawValue,
                                                            input: eventInput, detail: positionDetail)
            completion(RoutingResult(routes: [], failureReason: .SCALE_OFFSET_ERROR))
            return
        }

        let origin = RoutingStart(level_id: levelId, x: Int(latestResult.jupiter_pos.x), y: Int(latestResult.jupiter_pos.y), absolute_heading: Int(latestResult.jupiter_pos.heading))

        // end, waypoints는 고객사 좌표로 입력받으므로 내부 좌표로 변환한다.
        let destination = scaleOffset.toInternal(end)
        let internalWaypoints = waypoints.map { scaleOffset.toInternal($0) }
        let originBuildingName = latestResult.building_name
        print("(TJJupiterManager) requestRouting : origin= [levelId:\(origin.level_id), x:\(origin.x), y:\(origin.y), h:\(origin.absolute_heading)]")
        print("(TJJupiterManager) requestRouting : dest= [levelId:\(end.level_id), x:\(end.x), y:\(end.y)]")
        serviceManager.requestRouting(start: origin.toJupiter(),
                                       end: destination.toJupiter(),
                                       waypoints: internalWaypoints.map{$0.toJupiter()}, isVehicle: true, completion: { [weak self] _, navigationLevelRoutes, navigationFailureReason in
            print("(TJJupiterManager) requestRouting : navigationLevelRoutes= \(navigationLevelRoutes)")
            let routes = navigationLevelRoutes.flatMap { levelRoute -> [RoutingRoute] in
                // 리소스는 Jupiter 내부의 ResourceManager 인스턴스에 로드되므로 TJLabsResourceManager.shared가 아닌 serviceManager로 조회해야 한다.
                let levelName = self?.serviceManager?.getLevelName(levelId: levelRoute.levelId) ?? "unknown"
                // 경로 포인트는 해당 층의 scale/offset으로 고객사 좌표로 역변환한다(층 정보를 못 찾으면 요청 시 사용한 값을 쓴다).
                // levelId로 건물을 조회하는 API가 없어 출발 위치의 건물을 사용한다.
                let levelScaleOffset = self?.getScaleOffset(buildingName: originBuildingName, levelName: levelName) ?? scaleOffset
                return levelRoute.points.map { point in
                    let converted = levelScaleOffset.toCustomer(x: point.x, y: point.y)
                    return RoutingRoute(level_id: levelRoute.levelId, level_name: levelName, x: converted.x, y: converted.y)
                }
            }
            completion(RoutingResult(routes: routes, failureReason: navigationFailureReason?.toWrap()))
        })
    }

    // MARK: - Coordinate conversion
    // scale/offset은 Path Pixel(내부 좌표) -> 2D Local(고객사 좌표) 변환 계수다. (Warp의 ward 좌표 변환과 동일한 정의)
    // 내부 좌표 -> 고객사 좌표: customer = internal * scale + offset
    // 고객사 좌표 -> 내부 좌표: internal = (customer - offset) / scale
    private struct ScaleOffset {
        let scaleX: Float
        let scaleY: Float
        let offsetX: Float
        let offsetY: Float

        func toCustomer(x: Float, y: Float) -> (x: Float, y: Float) {
            return (x * scaleX + offsetX, y * scaleY + offsetY)
        }

        func toInternal(_ point: Point) -> Point {
            let x = (Float(point.x) - offsetX) / scaleX
            let y = (Float(point.y) - offsetY) / scaleY
            return Point(level_id: point.level_id, x: Int(x), y: Int(y))
        }

        func toCustomer(_ pos: Position) -> Position {
            let converted = toCustomer(x: pos.x, y: pos.y)
            return Position(x: converted.x, y: converted.y, heading: pos.heading)
        }
    }

    private func getScaleOffset(buildingName: String, levelName: String) -> ScaleOffset? {
        guard let scaleOffset = serviceManager?.getScaleOffset(sectorId: sectorId, buildingName: buildingName, levelName: levelName),
              scaleOffset.count >= 4,
              scaleOffset[0] != 0, scaleOffset[1] != 0 else { return nil }
        return ScaleOffset(scaleX: scaleOffset[0], scaleY: scaleOffset[1], offsetX: scaleOffset[2], offsetY: scaleOffset[3])
    }

    private func toCustomerResult(_ result: JupiterResult) -> JupiterResult {
        // scale/offset을 구할 수 없는 경우(예: 실외)에는 변환 없이 그대로 전달한다.
        guard let scaleOffset = getScaleOffset(buildingName: result.building_name, levelName: result.level_name) else {
            print("(TJJupiterManager) toCustomerResult : scaleOffset= nil [building:\(result.building_name), level:\(result.level_name)] -> no conversion")
            print("(TJJupiterManager) toCustomerResult : jupiter_pos= [x:\(result.jupiter_pos.x), y:\(result.jupiter_pos.y), h:\(result.jupiter_pos.heading)]")
            return result
        }
        var converted = result
        converted.jupiter_pos = scaleOffset.toCustomer(result.jupiter_pos)
        converted.navi_pos = result.navi_pos.map { scaleOffset.toCustomer($0) }
        print("(TJJupiterManager) toCustomerResult : scaleOffset= [building:\(result.building_name), level:\(result.level_name), scaleX:\(scaleOffset.scaleX), scaleY:\(scaleOffset.scaleY), offsetX:\(scaleOffset.offsetX), offsetY:\(scaleOffset.offsetY)]")
        print("(TJJupiterManager) toCustomerResult : jupiter_pos before= [x:\(result.jupiter_pos.x), y:\(result.jupiter_pos.y), h:\(result.jupiter_pos.heading)] after= [x:\(converted.jupiter_pos.x), y:\(converted.jupiter_pos.y), h:\(converted.jupiter_pos.heading)]")
        if let before = result.navi_pos, let after = converted.navi_pos {
            print("(TJJupiterManager) toCustomerResult : navi_pos before= [x:\(before.x), y:\(before.y), h:\(before.heading)] after= [x:\(after.x), y:\(after.y), h:\(after.heading)]")
        }
        return converted
    }
}
