
import Foundation
import TJLabsAuth
import TJLabsCommon
import TJLabsHana
import TJLabsJupiter

public class TJHanaAuth {
    public static let shared = TJHanaAuth()
    
    var deviceModel: String = ""
    var deviceOsInfo: String = ""
    var deviceOsVersion: Int = 0
    var sdkVersion: String = ""
    
    init () {
        setDeviceInfo()
        let clientMeta = makeClientMeta()
        SecretConfig.set(customerKey: "HANA", clientMeta: clientMeta)
        TJLabsAuthOnPremiseConstants.setBaseURL(ON_PREMISE_BASE_URL)
        HanaOnPremiseNetworkConstants.setBaseURL(ON_PREMISE_BASE_URL)
    }
    
    private func setDeviceInfo() {
        deviceModel = UIDevice.modelName
        deviceOsInfo = UIDevice.current.systemVersion
        let arr = deviceOsInfo.components(separatedBy: ".")
        deviceOsVersion = Int(arr[0]) ?? 0
    }
    
    private func makeClientMeta() -> ClientMeta {
        let clientSdks = [
            SdkMeta(name: "TJLabsAuth", version: "1.0.7"),
            SdkMeta(name: "TJLabsCommon", version: "1.0.7"),
            SdkMeta(name: "TJLabsResource", version: "0.1.13"),
            SdkMeta(name: "TJLabsJupiter", version: "2.0.16"),
            SdkMeta(name: "TJLabsHana", version: "1.1.3")
        ]
        
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let appVersion: String = version + "(\(build))"
        let appPackage: String = bundleIdentifier
        let deviceMode: String = self.deviceModel
        let osVersion: String = self.deviceOsInfo
        
        let clientMeta = ClientMeta(
            app_version: appVersion,
            app_package: appPackage,
            device_model: deviceMode,
            os_version: osVersion,
            sdks: clientSdks
        )
        
        return clientMeta
    }
    
    public func auth(accessKey: String, secretAccessKey: String, completion: @escaping (Int, Bool) -> Void) {
        HanaLogger.setDebugOption(set: false)
        JupiterLogger.setDebugOption(set: false)
        
        TJLabsAuthManager.shared.auth(accessKey: accessKey, secretAccessKey: secretAccessKey, completion: completion)
    }
}
