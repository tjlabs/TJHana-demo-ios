# TJHanaSDK
### Version 1.1.9

[![CI Status](https://img.shields.io/travis/tjlabs-dev/TJHanaSDK.svg?style=flat)](https://travis-ci.org/tjlabs-dev/TJHanaSDK)
[![Version](https://img.shields.io/cocoapods/v/TJHanaSDK.svg?style=flat)](https://cocoapods.org/pods/TJHanaSDK)
[![License](https://img.shields.io/cocoapods/l/TJHanaSDK.svg?style=flat)](https://cocoapods.org/pods/TJHanaSDK)
[![Platform](https://img.shields.io/cocoapods/p/TJHanaSDK.svg?style=flat)](https://cocoapods.org/pods/TJHanaSDK)

TJHanaSDK is an iOS SDK for TJLabs Hana indoor services.

It provides authentication, Warp-based ward interaction UI, Venus-based indoor result delivery, and Jupiter-based indoor positioning and navigation features in a single SDK.

---

## ✨ Features

- 🔐 SDK authentication
- 🫧 Warp ward detection and click interaction
- 📍 Venus indoor result delivery
- 🧭 Jupiter indoor positioning and navigation
- 🔄 Real-time delegate-based event handling

---

## 📦 Requirements

- iOS 16.0+
- Swift 5.0+
- Info.plist
    - Privacy - Motion Usage Description
    - Privacy - Bluetooth Peripheral Usage Description
    - Privacy - Bluetooth Always Usage Description
    - Privacy - Location When In Use Usage Description
    - App Transport Security Settings
        - Allow Arbitrary Loads - YES
- Recommended device capabilities
    - Accelerometer
    - Gyroscope
    - Magnetometer
    - Bluetooth Low Energy
- Recommended background modes when continuous indoor service is required
    - App communicates using CoreBluetooth
    - App registers for location updates

---

## 🚀 Installation

### CocoaPods

```ruby
pod 'TJHanaSDK'
```
## 📌 Example

If you cannot find `TJHanaSDK` in CocoaPods, add the source below to your `Podfile`.

```ruby
source 'https://github.com/CocoaPods/Specs.git'
```

---

## 🏁 Guide

- If you need a more detailed guide, please refer to the links below.
- SDK Guide: https://tjlabs.notion.site/Hana-API-Reference-335aef6d5b728045813bfb783b945940?source=copy_link
- Authentication Guide: https://www.notion.so/tjlabs/SDK-Authorization-33eaef6d5b728034856ddc23489588f0?source=copy_link
- Demo Application : https://github.com/tjlabs/TJHana-demo-ios.git

### 1. Import

```swift
import TJHanaSDK
```

### 2. Authentication

- You must authenticate before using Warp, Venus, or Jupiter.

```swift
TJHanaAuth.shared.auth(
    accessKey: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_ACCESS_KEY"
) { code, success in
    print("Auth:", success, "code:", code)
}
```

---

## 🫧 Warp

`TJWarpView` provides a ward interaction view that can be attached to your screen and started after initialization.

### Initialize and Start

```swift
final class WarpViewController: UIViewController, TJWarpViewDelegate {
    private let warpView = TJWarpView()

    override func viewDidLoad() {
        super.viewDidLoad()

        warpView.delegate = self
        warpView.initialize(id: "USER_ID", sectorId: 1, forceUpdate: true)
    }

    func onInitSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpInitErrorCode?) {
        guard isSuccess else { return }

        warpView.startService()
        warpView.configureFrame(to: self.view, warpImage: UIImage(named: "ic_warp"))
    }
}
```

### Stop

```swift
warpView.stopService()
```

### Delegate

```swift
extension ViewController: TJWarpViewDelegate {
    func onInitSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpInitErrorCode?) {}

    func onWarpSuccess(_ view: TJWarpView, _ isSuccess: Bool, _ code: WarpErrorCode?) {}

    func onClick(_ view: TJWarpView, warpWards: [WarpWard]) {}
    
    func onWarpSelectionChanged(_ view: TJWarpView, warpWards: [WarpWard]) {}
}
```

### Core Models

```swift
public struct WarpWard: Codable, Equatable {
    public var id: Int
    public var level_id: Int
    public var name: String
    public var x: Double
    public var y: Double
    public var rssi: Int
    public var detected_rssi: Int
    public var contents: [WardContents]
}

public struct WardContents: Codable {
    public let id: Int
    public let name: String
    public let url: URL
}
```

---

## 📍 Venus

`TJVenusManager` provides indoor result delivery through delegate callbacks.

### Initialize and Start

```swift
final class VenusViewController: UIViewController, TJVenuseManagerDelegate {
    private var venusManager: TJVenusManager?

    override func viewDidLoad() {
        super.viewDidLoad()

        let manager = TJVenusManager(id: "USER_ID", sectorId: 1, forceUpdate: true)
        // Set the delegate right after init. Init results (including failures) are delivered asynchronously.
        manager.delegate = self
        venusManager = manager
    }

    func onInitSuccess(_ manager: TJVenusManager, _ isSuccess: Bool, _ code: VenusInitErrorCode?) {
        guard isSuccess else { return }
        manager.startService()
    }
}
```

### Stop

```swift
venusManager?.stopService()
```

### Delegate

```swift
extension ViewController: TJVenuseManagerDelegate {
    func onInitSuccess(_ manager: TJVenusManager, _ isSuccess: Bool, _ code: VenusInitErrorCode?) {}

    func onVenusSuccess(_ manager: TJVenusManager, _ isSuccess: Bool, _ code: VenusErrorCode?) {}

    func onVenusResult(_ manager: TJVenusManager, _ result: VenusResult) {}
}
```

### VenusResult

```swift
public struct VenusResult: Codable {
    public let mobile_time: Int
    public let building_id: Int
    public let building_name: String
    public let level_id: Int
    public let level_name: String
    public let x: Double
    public let y: Double
}
```

---

## 🧭 Jupiter

`TJJupiterManager` provides indoor positioning, in/out state changes, destination updates, and routing requests.

### Initialize

- Initialization starts automatically after `init`, and its result is delivered through `onInitSuccess`.
- Set the `delegate` right after `init`, in the same execution flow on the main thread. Init failures such as `NOT_AUTHORIZED`, `NETWORK_DISCONNECT`, and `INVALID_ID` are delivered through the delegate as well.
- Call `TJHanaAuth.shared.auth` before creating `TJJupiterManager`. Otherwise `onInitSuccess` reports `NOT_AUTHORIZED`.
- Start the service after `onInitSuccess` reports success.

```swift
let manager = TJJupiterManager(id: "USER_ID", sectorId: 1, debugOption: false)
manager.delegate = self

func onInitSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterInitErrorCode?) {
    guard isSuccess else {
        print("Jupiter init failed:", code as Any)
        return
    }
    manager.startService(resultIntervalMs: 1000)
}
```

### Set Result Interval

- `setResultInterval(milliseconds:)` sets how often positioning results are delivered through `onJupiterResult`.
- It can be called at any time after `init`. If the service is already running, the new interval is applied immediately.
- The value is clamped to a minimum of `1` ms. If not set, the interval defaults to `1000` ms.

```swift
manager.setResultInterval(milliseconds: 500)
```

### Start Service

- You can also pass the delivery interval directly to `startService` via `resultIntervalMs` (defaults to `1000` ms).
- When both are used, the value passed to `startService` takes precedence.

```swift
manager.startService(resultIntervalMs: 1000)
```

### Stop Service

```swift
manager.stopService { success, message in
    print("Stopped:", success, "message:", message)
}
```

### Set Navigation Destination

```swift
manager.setNavigationDestination(
    dest: Point(level_id: 2, x: 120, y: 240)
)
```

### Request Routing

- The route starts from the latest positioning result, so call it after `onJupiterResult` has delivered at least one result. Otherwise the request fails with `NO_CURRENT_POSITION`.
- `end` and `waypoints` use your (customer) coordinates, and the returned route points are converted back to the same coordinate system.

```swift
manager.requestRouting(
    end: Point(level_id: 2, x: 120, y: 240),
    waypoints: []
) { result in
    print("Routes:", result.routes)
    print("Failure reason:", result.failureReason as Any)
}
```

### Delegate

```swift
extension ViewController: TJJupiterManagerDelegate {
    func onInitSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterInitErrorCode?) {}

    func onJupiterSuccess(_ manager: TJJupiterManager, _ isSuccess: Bool, _ code: JupiterErrorCode?) {}

    func onJupiterReport(_ manager: TJJupiterManager, _ code: JupiterServiceCode, _ msg: String) {}

    func onJupiterResult(_ manager: TJJupiterManager, _ result: JupiterResult) {}

    func isJupiterInOutStateChanged(_ manager: TJJupiterManager, _ state: InOutState) {}

    func isUserArrived() {}
    
    func isUserGuidanceOut() {}

    func isNavigationRouteChanged(_ manager: TJJupiterManager, _ routes: [(String, String, Float, Float)]) {}

    func isNavigationRouteFailed(_ manager: TJJupiterManager, _ reason: NavigationRouteFailureReason) {}

    func isWaypointChanged(_ manager: TJJupiterManager, _ waypoints: [[Double]]) {}
}
```

### JupiterResult

```swift
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
```

### Core Models

```swift
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
}

public struct Point: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
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
}
```

### Core Enums

```swift
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
    case INTERNAL_ERROR = "internal_error"           // kept for compatibility; no longer delivered
    // Before the request is sent
    case NO_CURRENT_POSITION = "no_current_position" // no positioning result yet
    case LEVEL_NOT_FOUND = "level_not_found"         // level id of the current position not found
    case SCALE_OFFSET_ERROR = "scale_offset_error"   // coordinate conversion info of the current level not found
    // Route request
    case TOO_CLOSE = "too_close"                     // destination is too close to the origin on the same level
    case NETWORK_ERROR = "network_error"             // server unreachable (timeout, connection lost, ...)
    case REQUEST_ERROR = "request_error"             // failed to build the request (encoding, URL, access token)
    case REQUEST_REJECTED = "request_rejected"       // server rejected the request (4xx)
    case SERVER_ERROR = "server_error"               // server error (5xx)
    case INVALID_RESPONSE = "invalid_response"       // failed to parse the server response
    case INVALID_ROUTE = "invalid_route"             // the returned route does not match the loaded map
    case NOT_READY = "not_ready"                     // service has not been started
    case CANCELLED = "cancelled"                     // service stopped before the response arrived
}
```
---
## 📌 Example

- For a more detailed example, please refer to the demo project at the link below.
- https://github.com/tjlabs/TJJupiterVM-demo-ios
---
## 📄 License

See the [LICENSE](LICENSE) file for details.
