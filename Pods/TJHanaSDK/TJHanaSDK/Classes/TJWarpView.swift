
import TJLabsHana

public class TJWarpView: UIView, TJLabsHana.WarpViewDelegate {
    public func onInitSuccess(_ view: TJLabsHana.WarpView, _ isSuccess: Bool, _ code: TJLabsHana.WarpInitErrorCode?) {
        delegate?.onInitSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onWarpSuccess(_ view: TJLabsHana.WarpView, _ isSuccess: Bool, _ code: TJLabsHana.WarpErrorCode?) {
        delegate?.onWarpSuccess(self, isSuccess, code?.toWrap())
    }
    
    public func onClick(_ view: TJLabsHana.WarpView, warpWards: [TJLabsHana.WarpWard]) {
        delegate?.onClick(self, warpWards: warpWards.map { $0.toWrap() })
    }
    
    public func onWarpSelectionChanged(_ view: TJLabsHana.WarpView, warpWards: [TJLabsHana.WarpWard]) {
        delegate?.onWarpSelectionChanged(self, warpWards: warpWards.map { $0.toWrap()} )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isHidden = true
    }
    
    deinit {
        stopService()
        warpView.delegate = nil
    }
    
    private var id: String?
    var warpView = WarpView()
    public weak var delegate: TJWarpViewDelegate?
    
    public func initialize(id: String, sectorId: Int = HANA_SECTOR_ID, forceUpdate: Bool = false) {
        warpView.delegate = self
        warpView.initialize(id: id, sectorId: sectorId, forceUpdate: forceUpdate)
    }
    
    public func configureFrame(to matchView: UIView, warpImage: UIImage? = nil) {
        warpView.isHidden = false
        warpView.configureFrame(to: matchView, warpImage: warpImage)
    }
    
    public func startService() {
        warpView.startService()
    }
    
    public func stopService() {
        warpView.stopService()
    }
    
    public func getVisibility() -> Bool {
        return warpView.getVisibility()
    }
    
    public func setVisibility(isVisible: Bool) {
        warpView.setVisibility(isVisible: isVisible)
    }
    
    public func setSelectionInterval(seconds: TimeInterval) {
        warpView.setSelectionInterval(seconds: seconds)
    }
}
