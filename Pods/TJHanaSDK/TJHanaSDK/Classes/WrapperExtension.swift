
import Foundation
import TJLabsCommon
import TJLabsJupiter
import TJLabsHana

// MARK: - To Common
extension UserMode {
    func toJupiter() -> TJLabsCommon.UserMode {
        return TJLabsCommon.UserMode(rawValue: self.rawValue) ?? .MODE_AUTO
    }
}

// MARK: - To Jupiter
extension RoutingStart {
    func toJupiter() -> TJLabsJupiter.RoutingStart {
        return TJLabsJupiter.RoutingStart(level_id: self.level_id,
                                          x: self.x,
                                          y: self.y,
                                          absolute_heading: self.absolute_heading)
    }
}

extension Point {
    func toJupiter() -> TJLabsJupiter.Point {
        return TJLabsJupiter.Point(level_id: self.level_id, x: self.x, y: self.y)
    }
}

// MARK: - To Wrap (Warp)
extension TJLabsHana.WarpInitErrorCode {
    func toWrap() -> WarpInitErrorCode {
        return WarpInitErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsHana.WarpErrorCode {
    func toWrap() -> WarpErrorCode {
        return WarpErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsHana.WarpWard {
    func toWrap() -> WarpWard {
        return WarpWard(
            id: self.id,
            level_id: self.level_id,
            name: self.name,
            x: self.x,
            y: self.y,
            rssi: self.rssi,
            detected_rssi: self.detected_rssi,
            contents: self.contents.map { $0.toWrap() }
        )
    }
}

extension TJLabsHana.WardContents {
    func toWrap() -> WardContents {
        return WardContents(
            id: self.id,
            name: self.name,
            url: self.url
        )
    }
}

extension TJLabsHana.WarpSectorInfo {
    func toWrap() -> WarpSectorInfo {
        return WarpSectorInfo(
            id: self.id,
            name: self.name,
            buildings: self.buildings.map { $0.toWrap() }
        )
    }
}

extension TJLabsHana.WarpBuildingInfo {
    func toWrap() -> WarpBuildingInfo {
        return WarpBuildingInfo(
            id: self.id,
            name: self.name,
            levels: self.levels.map { $0.toWrap() }
        )
    }
}

extension TJLabsHana.WarpLevelInfo {
    func toWrap() -> WarpLevelInfo {
        return WarpLevelInfo(
            id: self.id,
            name: self.name,
            mapImage: self.mapImage?.toWrap(),
            wards: self.wards.map { $0.toWrap() }
        )
    }
}

extension TJLabsHana.WarpMapImage {
    func toWrap() -> WarpMapImage {
        return WarpMapImage(
            building_id: self.building_id,
            building_name: self.building_name,
            level_id: self.level_id,
            level_name: self.level_name,
            url: self.url,
            image_width: self.image_width,
            image_height: self.image_height,
            scale_x: self.scale_x,
            scale_y: self.scale_y,
            offset_x: self.offset_x,
            offset_y: self.offset_y
        )
    }
}

// MARK: - To Wrap (Venus)
extension TJLabsHana.VenusInitErrorCode {
    func toWrap() -> VenusInitErrorCode {
        return VenusInitErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsHana.VenusErrorCode {
    func toWrap() -> VenusErrorCode {
        return VenusErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsHana.VenusResult {
    func toWrap() -> VenusResult {
        return VenusResult(mobile_time: self.mobile_time,
                           building_id: self.building_id,
                           building_name: self.building_name,
                           level_id: self.level_id,
                           level_name: self.level_name,
                           x: self.x, y: self.y)
    }
}

// MARK: - To Wrap (Jupiter)
extension TJLabsJupiter.InOutState {
    func toWrap() -> InOutState {
        return InOutState(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsJupiter.InitErrorCode {
    func toWrap() -> JupiterInitErrorCode {
        return JupiterInitErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsJupiter.JupiterErrorCode {
    func toWrap() -> JupiterErrorCode {
        return JupiterErrorCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsJupiter.NavigationRouteFailureReason {
    func toWrap() -> NavigationRouteFailureReason {
        return NavigationRouteFailureReason(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsJupiter.JupiterServiceCode {
    func toWrap() -> JupiterServiceCode {
        return JupiterServiceCode(rawValue: self.rawValue) ?? .UNKNOWN
    }
}

extension TJLabsJupiter.Position {
    func toWrap() -> Position {
        return Position(
            x: self.x,
            y: self.y,
            heading: self.heading
        )
    }
}

extension TJLabsJupiter.LLH {
    func toWrap() -> LLH {
        return LLH(
            lat: self.lat,
            lon: self.lon,
            azimuth: self.azimuth
        )
    }
}

extension TJLabsJupiter.JupiterResult {
    func toWrap() -> JupiterResult {
        return JupiterResult(
            mobile_time: self.mobile_time,
            index: self.index,
            building_name: self.building_name,
            level_name: self.level_name,
            jupiter_pos: self.jupiter_pos.toWrap(),
            navi_pos: self.navi_pos?.toWrap(),
            llh: self.llh?.toWrap(),
            velocity: self.velocity,
            is_vehicle: self.is_vehicle,
            is_indoor: self.is_indoor,
            validity_flag: self.validity_flag
        )
    }
}
