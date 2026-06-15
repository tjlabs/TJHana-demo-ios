
import Foundation
import TJLabsHana

public class TJVenusManager: TJLabsHana.VenusServiceManagerDelegate {
    public func onInitSuccess(_ manager: TJLabsHana.VenusServiceManager, _ isSuccess: Bool, _ code: TJLabsHana.VenusInitErrorCode?) {
        guard !isInvalidated else { return }
        delegate?.onInitSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onVenusSuccess(_ manager: TJLabsHana.VenusServiceManager, _ isSuccess: Bool, _ code: TJLabsHana.VenusErrorCode?) {
        guard !isInvalidated else { return }
        delegate?.onVenusSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onVenusResult(_ manager: TJLabsHana.VenusServiceManager, _ result: TJLabsHana.VenusResult) {
        guard !isInvalidated else { return }
        delegate?.onVenusResult(self, result.toWrap())
    }
    
    
    private var region: String = ""
    private var id: String = ""
    private var sectorId: Int = 0
    public weak var delegate: TJVenuseManagerDelegate?
    var serviceManager: VenusServiceManager?
    private var isInvalidated = false
    
    public init(id: String, sectorId: Int = HANA_SECTOR_ID, forceUpdate: Bool = false) {
        self.id = id
        self.sectorId = sectorId
        
        self.serviceManager = VenusServiceManager(id: id, region: HanaRegion.KOREA.rawValue, sectorId: sectorId, forceUpdate: forceUpdate)
        self.serviceManager?.delegate = self
    }
    
    deinit {
        invalidate()
    }
    
    public func startService() {
        serviceManager?.startService()
    }
    
    public func stopService() {
        serviceManager?.stopService()
    }
    
    public func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        
        delegate = nil
        serviceManager?.delegate = nil
        serviceManager?.stopService()
        serviceManager = nil
    }
}
