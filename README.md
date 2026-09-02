# TJHana-demo-ios

## Overview

TJHana-demo-ios is a minimal iOS sample app for integrating **TJLabs Hana SDK** with CocoaPods.

<!-- JUPITER_SDK_VERSION_START -->
Jupiter SDK version: 2.0.16
<!-- JUPITER_SDK_VERSION_END -->

<!-- HANA_SDK_IOS_VERSION_START -->
Hana SDK (CocoaPods): TJHanaSDK 1.1.2
<!-- HANA_SDK_IOS_VERSION_END -->

The app demonstrates Hana SDK flows with:
- Authentication (`AUTH`)
- Warp initialize/start flow
- Warp floating view attach and ward click handling
- Venus initialize/start flow
- Venus result callback handling
- Jupiter initialize/start/stop flow (vehicle/DR mode)
- Jupiter result callback and `requestRouting` handling

## Features

- Hana SDK auth flow example
- Warp view attach with custom floating container
- Warp ward click callback handling
- Venus service result callback (`onVenusResult`)
- Runtime permission request flow (Location/Bluetooth)
- Service entry buttons enabled only after auth success
- Jupiter DR-mode positioning with live result fields and routing request example

## Requirements

- iOS `16.0+`
- Xcode `15+`
- Swift `5`
- CocoaPods `1.16+`

### Required permissions

Declare in `Info.plist`:

- `Privacy - Motion Usage Description`
- `Privacy - Bluetooth Peripheral Usage Description`
- `Privacy - Bluetooth Always Usage Description`
- `Privacy - Location When In Usage Description`

Required device capabilities:

- `Accelerometer`
- `Gyroscope`
- `Magnetometer`
- `Bluetooth Low Energy`

Required background modes:

- `App communicates using CoreBluetooth`
- `App registers for location updates`

Runtime permission flow in this demo requires:
- Location When In Use
- Bluetooth
- Motion

## Setup

### 1. Add dependency

This demo uses the released pod:

```ruby
# Podfile
platform :ios, '16.0'

source 'https://github.com/CocoaPods/Specs.git'

target 'TJHanaDemo' do
  use_frameworks!

  pod 'TJHanaSDK', '1.1.2'
end
```

To develop against a local SDK checkout instead, replace it with a path pod:

```ruby
pod 'TJHanaSDK', :path => '/Users/leo/SwiftProjects/TJHanaSDK'
```

### 2. Install Pods

```bash
pod install
```

### 3. Open workspace

```bash
open TJHanaDemo.xcworkspace
```

## Quick Guide

### 1. Configure credentials

Set credentials in [MainViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/MainViewController.swift:16):

```swift
private let accessKey = "YOUR_ACCESS_KEY"
private let secretAccessKey = "YOUR_SECRET_ACCESS_KEY"
```

### 2. Authenticate

```swift
TJHanaAuth.shared.auth(accessKey: accessKey, secretAccessKey: secretAccessKey) { code, isSuccess in
    // handle auth result
}
```

### 3. Initialize services

After auth success:

```swift
warpView.initialize(id: userId, sectorId: sectorId, forceUpdate: true)

let venusManager = TJVenusManager(id: userId, sectorId: sectorId, forceUpdate: true)
venusManager.delegate = self
```

### 4. Start services

Start service in each init success callback:

```swift
warpView.startService()
venusManager.startService()
```

### 5. Warp UI / interaction

Attach the Warp floating view and handle ward clicks:

```swift
warpView.configureFrame(to: floatingContainerView, warpImage: UIImage(named: "ic_warp"))
```

```swift
func onClick(_ view: TJWarpView, warpWards: [WarpWard]) {
    // handle clicked wards
}
```

### 6. Stop services

```swift
warpView.stopService()
venusManager.stopService()
```

### 7. Jupiter flow

`JupiterViewController` demonstrates the full Jupiter positioning lifecycle. The manager
initializes automatically on creation; start/stop are driven from the screen's buttons and
positioning always runs in vehicle (DR) mode:

```swift
let jupiterManager = TJJupiterManager(id: userId, debugOption: false)
jupiterManager.delegate = self

// After onInitSuccess:
jupiterManager.startService()

// Request a route to a destination point:
jupiterManager.requestRouting(end: routingEnd) { result in
    // handle RoutingResult
}

jupiterManager.stopService { isSuccess, msg, result in
    // handle stop result
}
```

Positioning results arrive through `TJJupiterManagerDelegate`:

```swift
func onJupiterResult(_ manager: TJJupiterManager, _ result: JupiterResult) {
    // handle live position result
}
```

## Notes

- Jupiter positioning always runs in vehicle (DR) mode in this demo.
- For reliable BLE and indoor positioning behavior, test on a real iPhone rather than only in the simulator.
