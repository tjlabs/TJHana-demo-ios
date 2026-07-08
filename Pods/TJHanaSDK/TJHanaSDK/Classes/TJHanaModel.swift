
import TJLabsCommon
import TJLabsJupiter

let SAMPLE_WARD_X: Int = 70
let SAMPLE_WARD_Y: Int = 10

let SAMPLE_ROUTING_RESULT = RoutingResult(routes:
                                        [RoutingRoute(level_id: 700, level_name: "B2", x: 70, y: 10),
                                         RoutingRoute(level_id: 700, level_name: "B2", x: 70, y: 18),
                                         RoutingRoute(level_id: 700, level_name: "B2", x: 10, y: 18),
                                         RoutingRoute(level_id: 700, level_name: "B2", x: 10, y: 29),
                                         RoutingRoute(level_id: 700, level_name: "B2", x: 5, y: 29)],
                                          failureReason: nil)
// Mock 결과 전달 주기 및 가정 이동 속도
let MOCK_JUPITER_INTERVAL: TimeInterval = 0.2   // delegate 전달 간격 (초)
let MOCK_JUPITER_SPEED_MPS: Float = 4.0         // 사용자가 이동한다고 가정하는 속도 (m/s)

// SAMPLE_ROUTING_RESULT의 element를 순서대로 지나는 mock JupiterResult 목록.
// 인접 element 사이를 (속도 × 간격)m 만큼씩 등속으로 보간해 좌표를 생성한다.
let SAMPLE_MOCK_JUPITER_RESULTS: [JupiterResult] = makeMockJupiterResults(from: SAMPLE_ROUTING_RESULT)

// 라우팅 경로(폴리라인)를 등속으로 리샘플링해 mock JupiterResult 배열을 만든다.
// - step = speedMps × intervalSec (매 tick 이동 거리, 좌표 단위 = m 가정)
// - heading = 직전 element → 다음 element 방향의 방위각(도, [0,360)).
//   예) (70,10) → (70,18) 은 +y 방향이므로 90도.
func makeMockJupiterResults(from routing: RoutingResult,
                            speedMps: Float = MOCK_JUPITER_SPEED_MPS,
                            intervalSec: Float = Float(MOCK_JUPITER_INTERVAL)) -> [JupiterResult] {
    let routes = routing.routes
    let intervalMs = Int((intervalSec * 1000).rounded())

    func makeResult(index: Int, x: Float, y: Float, heading: Float, route: RoutingRoute, velocity: Float) -> JupiterResult {
        let pos = Position(x: x, y: y, heading: heading)
        return JupiterResult(
            mobile_time: index * intervalMs,   // 상대 오프셋(ms). 실제 전달 시점에 현재 시각으로 덮어씀.
            index: index,
            building_name: "",
            level_name: route.level_name,
            jupiter_pos: pos,
            navi_pos: pos,
            llh: nil,
            velocity: velocity,
            is_vehicle: false,
            is_indoor: true,
            validity_flag: 1
        )
    }

    guard routes.count >= 2 else {
        if let only = routes.first {
            return [makeResult(index: 0, x: only.x, y: only.y, heading: 0, route: only, velocity: 0)]
        }
        return []
    }

    // 누적 거리 + 세그먼트별 heading 계산
    var cumulative: [Float] = [0]
    var headings: [Float] = []
    for i in 0..<(routes.count - 1) {
        let dx = routes[i + 1].x - routes[i].x
        let dy = routes[i + 1].y - routes[i].y
        cumulative.append(cumulative[i] + (dx * dx + dy * dy).squareRoot())
        var degrees = atan2(Double(dy), Double(dx)) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        headings.append(Float(degrees))
    }
    let total = cumulative.last ?? 0

    let step = max(speedMps * intervalSec, 0.0001)
    var results: [JupiterResult] = []
    var segment = 0
    var index = 0
    var distance: Float = 0
    while distance <= total + 0.0001 {
        while segment < headings.count - 1 && distance > cumulative[segment + 1] {
            segment += 1
        }
        let segLength = cumulative[segment + 1] - cumulative[segment]
        let t = segLength > 0 ? (distance - cumulative[segment]) / segLength : 0
        let x = routes[segment].x + t * (routes[segment + 1].x - routes[segment].x)
        let y = routes[segment].y + t * (routes[segment + 1].y - routes[segment].y)
        results.append(makeResult(index: index,
                                  x: x,
                                  y: y,
                                  heading: headings[segment],
                                  route: routes[segment + 1],
                                  velocity: speedMps))
        index += 1
        distance += step
    }
    return results
}

// MARK: - Hana
public enum HanaRegion: String {
    case KOREA = "KOREA"
    case US_EAST = "US_EAST"
    case CANADA = "CANADA"
}

// MARK: - Warp
public protocol TJWarpViewDelegate: AnyObject {
    func onInitSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpInitErrorCode?)
    func onWarpSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpErrorCode?)
    func onClick(_ view: TJWarpView, warpWards: [WarpWard])
    func onWarpSelectionChanged(_ view: TJWarpView, warpWards: [WarpWard])
}

public enum WarpInitErrorCode: Int {
    case UNKNOWN = -1
    case INVALID_ID = 0
    case RESOURCE_FAIL = 1
}

public enum WarpErrorCode: Int {
    case UNKNOWN = -1
    case NOT_INITIALIZED = 0
    case DUPLICATE_SERVICE = 1
    case BLE_NOT_AUTHORIZED = 2
    case GENERATOR_FAIL = 3
}

public struct WarpWard: Codable, Equatable {
    public var id: Int
    public var name: String
    public var x: Int
    public var y: Int
    public var rssi: Int
    public var contents: [WardContents]
    
    public init(id: Int, name: String, x: Int, y: Int, rssi: Int, contents: [WardContents]) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.rssi = rssi
        self.contents = contents
    }
}

public struct WardContents: Codable, Equatable {
    public var id: Int
    public var name: String
    public var url: URL
    
    public init(id: Int, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

// MARK: - Venus
public protocol TJVenuseManagerDelegate: AnyObject {
    func onInitSuccess(_ manager: TJVenusManager, _ isSuccess: Bool, _ code: VenusInitErrorCode?)
    func onVenusSuccess(_ manager: TJVenusManager, _ isSuccess: Bool, _ code: VenusErrorCode?)
    func onVenusResult(_ manager: TJVenusManager, _ result: VenusResult)
}

public enum VenusInitErrorCode: Int {
    case UNKNOWN = -1
    case INVALID_ID = 0
    case RESOURCE_FAIL = 1
}

public enum VenusErrorCode: Int {
    case UNKNOWN = -1
    case NOT_INITIALIZED = 0
    case DUPLICATE_SERVICE = 1
    case BLE_NOT_AUTHORIZED = 2
    case GENERATOR_FAIL = 3
}

public struct VenusResult: Codable {
    public let mobile_time: Int
    public let building_id: Int
    public let building_name: String
    public let level_id: Int
    public let level_name: String
    public let x: Int
    public let y: Int
    
    public init(mobile_time: Int, building_id: Int, building_name: String, level_id: Int, level_name: String, x: Int, y: Int) {
        self.mobile_time = mobile_time
        self.building_id = building_id
        self.building_name = building_name
        self.level_id = level_id
        self.level_name = level_name
        self.x = x
        self.y = y
    }
}

// MARK: - Jupiter
public protocol TJJupiterManagerDelegate: AnyObject {
    func onInitSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterInitErrorCode?)
    func onJupiterSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterErrorCode?)
    func onJupiterReport(_ manager: TJJupiterManager, _ code: JupiterServiceCode, _ msg: String)
    func onJupiterResult(_ manager: TJJupiterManager, _ result: JupiterResult)
    func isJupiterInOutStateChanged(_ manager: TJJupiterManager, _ state: InOutState)
    func isUserGuidanceOut()
    func isUserArrived()
    func isNavigationRouteChanged(_ manager: TJJupiterManager, _ routes: [(String, String, Float, Float)])
    func isNavigationRouteFailed(_ manager: TJJupiterManager, _ reason: NavigationRouteFailureReason)
    func isWaypointChanged(_ manager: TJJupiterManager, _ waypoints: [[Double]])
}

public enum JupiterRegion: String {
    case KOREA = "KOREA"
    case US_EAST = "US_EAST"
    case CANADA = "CANADA"
}

public enum UserMode: String {
    case MODE_PEDESTRIAN = "PDR"
    case MODE_VEHICLE = "DR"
    case MODE_AUTO = "AUTO"
}

public enum InOutState: Int {
    case UNKNOWN = -1
    case OUT_TO_IN = 0
    case INDOOR = 1
    case IN_TO_OUT = 2
    case OUTDOOR = 3
}

public enum JupiterInitErrorCode: Int {
    case UNKNOWN = -1
    case NOT_AUTHORIZED = 0
    case INVALID_ID = 1
    case NETWORK_DISCONNECT = 2
    case LOGIN_FAIL = 3
    case LOAD_RESOURCE_FAIL = 4
}

public enum JupiterErrorCode: Int {
    case UNKNOWN = -1
    case NOT_INITIALIZED = 0
    case DUPLICATED_SERVICE = 1
    case GENERATOR_FAIL = 2
}

public enum JupiterServiceCode: Int {
    case UNKNOWN = -1
    case SERVICE_FAIL = 0
    case SERVICE_SUCCESS = 1
    case BECOME_BACKGROUND = 2
    case BECOME_FOREGROUND = 3
    case BLUETOOTH_UNAVAILABLE = 4
    case BLUETOOTH_OFF = 5
    case BLUETOOTH_SCAN_STOP = 6
    case NETWORK_DISCONNECT = 7
}

public enum NavigationRouteFailureReason: String, Codable {
    case UNKNOWN = "unknown"
    case SERVER_RESPONSE = "server_response"
    case TOO_CLOSE = "too_close"
}

public struct JupiterResult: Codable {
    public var mobile_time: Int
    public var index: Int
    public var building_name: String
    public var level_name: String
    public var jupiter_pos: Position
    public var navi_pos: Position?
    public var llh: LLH?
    public var velocity: Float
    public var is_vehicle: Bool
    public var is_indoor: Bool
    public var validity_flag: Int
}

public struct Position: Codable {
    public var x: Float
    public var y: Float
    public var heading: Float
}

public struct LLH: Codable {
    public var lat: Double
    public var lon: Double
    public var azimuth: Double
}

public struct RoutingStart: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
    public var absolute_heading: Int
    
    public init(level_id: Int, x: Int, y: Int, absolute_heading: Int) {
        self.level_id = level_id
        self.x = x
        self.y = y
        self.absolute_heading = absolute_heading
    }
}

public struct Point: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
    
    public init(level_id: Int, x: Int, y: Int) {
        self.level_id = level_id
        self.x = x
        self.y = y
    }
}

public struct RoutingResult: Codable {
    public let routes: [RoutingRoute]
    public let failureReason: NavigationRouteFailureReason?
}

public struct RoutingRoute: Codable {
    public let level_id: Int
    public let level_name: String
    public let x: Float
    public let y: Float

    public init(level_id: Int, level_name: String, x: Float, y: Float) {
        self.level_id = level_id
        self.level_name = level_name
        self.x = x
        self.y = y
    }
}
