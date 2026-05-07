# TJHanaDemo

`TJHanaDemo`는 `TJHanaSDK`의 주요 기능을 한 번에 확인할 수 있는 iOS 데모 앱입니다.  
메인 화면에서 SDK 인증을 수행한 뒤 `Warp`, `Venus`, `Jupiter` 화면으로 이동할 수 있으며, 현재 프로젝트에는 위치/블루투스 권한 요청 흐름도 포함되어 있습니다.

## Overview

이 앱은 UIKit 기반 샘플로 다음 내용을 보여줍니다.

- `HanaAuth.shared.auth(...)`를 통한 SDK 인증
- `TJWarpView` 초기화 및 ward 클릭 이벤트 처리
- `TJVenusManager` 초기화 및 실내 위치 결과 표시
- 위치/블루투스 권한 요청 및 설정 이동 처리
- `Jupiter` 화면 진입 구조

현재 `JupiterViewController`는 placeholder 화면만 제공하며, 실제 Jupiter 서비스 연동 예제는 아직 포함되어 있지 않습니다.

## Features

- 인증 전에는 `Warp`, `Venus`, `Jupiter` 버튼 비활성화
- 인증 성공 후 서비스 화면 진입 가능
- 앱 진입 시 위치 권한 요청
- 위치 권한 승인 후 블루투스 권한 요청 파이프라인 실행
- 권한 거부 시 설정 화면 이동 얼럿 제공
- `Warp`에서 ward 목록 표시
- `Venus`에서 `building / level / x / y` 결과 표시

## Requirements

- Xcode 15 이상
- iOS 16.6 이상 권장
- Swift 5
- CocoaPods 1.16+

실사용 테스트는 BLE와 위치 센서가 필요한 만큼 시뮬레이터보다 실제 iPhone에서 확인하는 편이 정확합니다.

## Project Structure

```text
TJHanaDemo/
├── TJHanaDemo/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── MainViewController.swift     # 인증 + 권한 요청 + 화면 진입
│   ├── WarpViewController.swift     # Warp 데모
│   ├── VenusViewController.swift    # Venus 데모
│   ├── JupiterViewController.swift  # Jupiter placeholder
│   ├── Base.lproj/
│   ├── Assets.xcassets/
│   └── Info.plist
├── TJHanaDemoTests/
├── TJHanaDemoUITests/
├── Podfile
├── TJHanaDemo.xcodeproj
└── TJHanaDemo.xcworkspace
```

## Setup

1. `Podfile`에 `TJHanaSDK` 의존성을 추가합니다.

```ruby
pod 'TJHanaSDK', '1.0.0'
```

2. 사내 Spec 저장소 또는 CocoaPods trunk 배포 전략을 사용하는 경우, 필요한 `source`를 `Podfile` 상단에 추가합니다.

```ruby
source 'https://github.com/CocoaPods/Specs.git'
```

3. Pods를 설치하거나 업데이트합니다.

```bash
pod install
```

4. 반드시 `.xcodeproj`가 아니라 `.xcworkspace`를 엽니다.

```bash
open TJHanaDemo.xcworkspace
```

## Configuration

### 1. SDK 인증 키

`MainViewController.swift`에 샘플 인증 키가 하드코딩되어 있습니다.

- [MainViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/MainViewController.swift:14)

배포 또는 실제 테스트 전에는 아래 값을 운영용 키로 교체해야 합니다.

```swift
private let accessKey = "YOUR_ACCESS_KEY"
private let secretAccessKey = "YOUR_SECRET_ACCESS_KEY"
```

### 2. Sector / User ID

현재 데모 화면들은 아래 값으로 초기화됩니다.

- `WarpViewController`: `warpUserId = "hana-example-user"`, `sectorId = 1`
- `VenusViewController`: `venusUserId = "hana-example-user"`, `sectorId = 1`

현장 환경에 맞는 사용자 ID와 sector ID로 변경해서 사용하면 됩니다.

## Permissions

이 프로젝트는 아래 권한 키를 사용합니다.

- `NSLocationWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

정의 위치:

- [Info.plist](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/Info.plist:5)

권한 요청 흐름은 메인 화면에 구현되어 있습니다.

1. `MainViewController` 진입
2. 위치 권한 요청
3. 위치 권한 허용 시 블루투스 권한 요청
4. 거부 상태면 설정 이동 얼럿 노출

구현 위치:

- [MainViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/MainViewController.swift:179)

## Screens

### Main

- SDK 인증 버튼 제공
- 인증 전에는 서비스 버튼 비활성화
- 권한 요청 및 상태 복귀 처리 수행

### Warp

- `TJWarpView` 초기화
- 서비스 시작
- ward 클릭 시 이름 목록 표시

구현 위치:

- [WarpViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/WarpViewController.swift:5)

### Venus

- `TJVenusManager` 초기화
- 서비스 시작
- 결과 수신 시 모바일 시간, 건물/레벨, X/Y 값 표시

구현 위치:

- [VenusViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/VenusViewController.swift:4)

### Jupiter

- 현재는 "아직 이용할 수 없습니다" placeholder 화면만 제공

구현 위치:

- [JupiterViewController.swift](/Users/leo/SwiftProjects/TJHanaDemo/TJHanaDemo/JupiterViewController.swift:3)

## Run

1. Xcode에서 `TJHanaDemo` 스킴 선택
2. 실제 iPhone 또는 iOS Simulator 선택
3. Build & Run
4. 위치/블루투스 권한 허용
5. `인증` 버튼 탭
6. 인증 성공 후 `Warp` 또는 `Venus` 화면 진입

## Build Status

현재 기준으로 아래 명령으로 앱 타깃 빌드 성공을 확인했습니다.

```bash
xcodebuild -workspace TJHanaDemo.xcworkspace -scheme TJHanaDemo -sdk iphonesimulator -configuration Debug build
```

## Known Notes

- 시뮬레이터에서는 블루투스/센서 동작이 제한될 수 있습니다.
- `Jupiter`는 아직 실제 SDK 연동 예제가 아닙니다. 실제 서비스구역에 인프라가 완전히 구축된 이후 지원합니다.

## License

이 저장소에는 별도 라이선스 파일이 포함되어 있지 않습니다.
