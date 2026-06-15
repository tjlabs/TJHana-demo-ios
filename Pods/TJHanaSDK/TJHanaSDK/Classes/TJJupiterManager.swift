
import Foundation
import TJLabsJupiter
import TJLabsHana
    
public class TJJupiterManager: NavigationManagerDelegate {
    
    public func onInitSuccess(_ isSuccess: Bool, _ code: TJLabsJupiter.InitErrorCode?) {
        delegate?.onInitSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onJupiterSuccess(_ isSuccess: Bool, _ code: TJLabsJupiter.JupiterErrorCode?) {
        delegate?.onJupiterSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onJupiterResult(_ result: TJLabsJupiter.JupiterResult) {
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
    public weak var delegate: TJJupiterManagerDelegate?
    
    var serviceManager: NavigationManager?
    
    public init(id: String, sectorId: Int = HANA_SECTOR_ID, debugOption: Bool = false) {
        self.id = id
        self.sectorId = sectorId
        
        self.serviceManager = NavigationManager(id: id, region: HanaRegion.KOREA.rawValue, sectorId: sectorId, debugOption: debugOption)
        self.serviceManager?.delegate = self
    }
    
    deinit {
        serviceManager?.delegate = nil
        
        serviceManager?.stopService(completion: {_, _ in})
        serviceManager = nil
    }
    
    public func startService(mode: UserMode) {
        serviceManager?.startService(mode: mode.toJupiter())
    }
    
    public func stopService(completion: @escaping (Bool, String) -> Void) {
        serviceManager?.stopService(completion: completion)
    }
    
    public func setNavigationDestination(dest: Point) {
        serviceManager?.setNaviDestination(dest: dest.toJupiter(), isVehicle: true)
    }
    
    public func requestRouting(start: RoutingStart, end: Point, waypoints: [Point] = []) {
        serviceManager?.requestRouting(start: start.toJupiter(),
                                       end: end.toJupiter(),
                                       waypoints: waypoints.map{$0.toJupiter()}, is_vehicle: true, completion: { _, _ in
            
        })
    }
}
