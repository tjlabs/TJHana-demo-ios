# TJHana-demo-ios

## Overview

TJHana-demo-ios is a minimal iOS sample app for integrating **TJLabs Hana SDK** with CocoaPods.

<!-- JUPITER_SDK_VERSION_START -->
Jupiter SDK version: 2.0.0
<!-- JUPITER_SDK_VERSION_END -->

<!-- HANA_SDK_IOS_VERSION_START -->
Hana SDK (CocoaPods): TJHanaSDK 1.0.0
<!-- HANA_SDK_IOS_VERSION_END -->

The app demonstrates Hana SDK flows with:
- Authentication (`AUTH`)
- Warp initialize/start flow
- Warp floating view attach and ward click handling
- Venus initialize/start flow
- Venus result callback handling
- Jupiter screen entry structure (placeholder)

## Features

- Hana SDK auth flow example
- Warp view attach with custom floating container
- Warp ward click callback handling
- Venus service result callback (`onVenusResult`)
- Runtime permission request flow (Location/Bluetooth)
- Service entry buttons enabled only after auth success
- Jupiter sample entry screen placeholder

## Requirements

- iOS `16.0+`
- Xcode `15+`
- Swift `5`
- CocoaPods `1.16+`

### Required permissions

Declare in `Info.plist`:

- `NSLocationWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

Runtime permission flow in this demo requires:
- Location When In Use
- Bluetooth

## Setup

### 1. Add dependency

This demo currently uses a local pod path:

```ruby
# Podfile
platform :ios, '16.0'

target 'TJHanaDemo' do
  use_frameworks!

  pod 'TJHanaSDK', :path => '/Users/leo/SwiftProjects/TJHanaSDK'
end
```

If you use a released pod instead of a local SDK path, replace it with:

```ruby
pod 'TJHanaSDK', '1.0.0'
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

Set credentials in [MainViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/MainViewController.swift:14):

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

## Notes

- The current `JupiterViewController` is a placeholder screen and does not yet start a live Jupiter service flow.
- For reliable BLE and indoor positioning behavior, test on a real iPhone rather than only in the simulator.
