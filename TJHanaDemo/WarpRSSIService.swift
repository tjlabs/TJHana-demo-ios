//
//  WarpRSSIService.swift
//  TJHanaDemo
//
//  Updates a ward's Warp RSSI threshold on the server:
//    ① Bearer token via TJLabsAuthManager.shared.getAccessToken
//    ② PUT {BASE}/v2/warp/wards/{id}/rssi { operating_system, rssi }
//
//  BASE_URL comes from TJLabsHana (warp service base URL).
//

import Foundation
import TJLabsAuth

final class WarpRSSIService {
    static let shared = WarpRSSIService()
    private init() {}

    private let operatingSystem = "iOS"

    enum ServiceError: LocalizedError {
        case invalidURL
        case http(status: Int, detail: String)
        case unauthorized
        case forbidden
        case tokenFailed(String)
        case transport(Error)
        case decoding

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "BASE_URL이 올바르지 않습니다."
            case .http(let status, let detail):
                return detail.isEmpty ? "요청 실패 (\(status))" : "요청 실패 (\(status)): \(detail)"
            case .unauthorized: return "토큰이 없거나 만료되었습니다 (401)."
            case .forbidden: return "액세스 키 역할이 'SDK 연동'이 아닙니다 (403)."
            case .tokenFailed(let detail): return "토큰 발급 실패: \(detail)"
            case .transport(let error): return "네트워크 오류: \(error.localizedDescription)"
            case .decoding: return "서버 응답을 해석하지 못했습니다."
            }
        }
    }

    // MARK: - Public

    /// Updates the iOS RSSI threshold for a ward. `baseURL` comes from
    /// `TJWarpView.getWarpBaseURL()`. Completion runs on the main thread.
    func updateWardRSSI(baseURL: String,
                        wardId: Int,
                        rssi: Int,
                        completion: @escaping (Result<Int, ServiceError>) -> Void) {
        fetchToken(update: false) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            case .success(let token):
                self.putRSSI(baseURL: baseURL, wardId: wardId, rssi: rssi, token: token) { putResult in
                    // A cached token may have expired server-side → force refresh and retry once.
                    if case .failure(.unauthorized) = putResult {
                        self.fetchToken(update: true) { retryToken in
                            switch retryToken {
                            case .failure(let error):
                                DispatchQueue.main.async { completion(.failure(error)) }
                            case .success(let fresh):
                                self.putRSSI(baseURL: baseURL, wardId: wardId, rssi: rssi, token: fresh) { retry in
                                    DispatchQueue.main.async { completion(retry) }
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async { completion(putResult) }
                    }
                }
            }
        }
    }

    // MARK: - Token

    /// Bearer token from the auth SDK. `update: true` forces a refresh.
    private func fetchToken(update: Bool, completion: @escaping (Result<String, ServiceError>) -> Void) {
        TJLabsAuthManager.shared.getAccessToken(update: update) { result in
            switch result {
            case .success(let token):
                print("(WarpRSSIService) getAccessToken success")
                completion(.success(token))
            case .failure(let reason, let statusCode, let message):
                let detail = "reason=\(reason), status=\(statusCode.map(String.init) ?? "-"), msg=\(message ?? "-")"
                print("(WarpRSSIService) getAccessToken failed: \(detail)")
                completion(.failure(.tokenFailed(detail)))
            }
        }
    }

    // MARK: - PUT rssi

    private func putRSSI(baseURL: String,
                         wardId: Int,
                         rssi: Int,
                         token: String,
                         completion: @escaping (Result<Int, ServiceError>) -> Void) {
        guard let url = URL(string: baseURL + "/wards/\(wardId)/rssi") else {
            completion(.failure(.invalidURL))
            return
        }
        print("(WarpRSSIService) putRSSI : url= \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["operating_system": operatingSystem, "rssi": rssi]
        )

        print("(WarpRSSIService) PUT \(url.absoluteString) body: operating_system=\(operatingSystem), rssi=\(rssi)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("(WarpRSSIService) PUT transport error: \(error.localizedDescription)")
                completion(.failure(.transport(error)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.decoding))
                return
            }
            let data = data ?? Data()
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("(WarpRSSIService) PUT status: \(http.statusCode), body: \(bodyString)")
            guard (200..<300).contains(http.statusCode) else {
                completion(.failure(Self.mapError(status: http.statusCode, data: data)))
                return
            }
            let returned = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["rssi"] as? Int
            completion(.success(returned ?? rssi))
        }.resume()
    }

    private static func mapError(status: Int, data: Data) -> ServiceError {
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden
        default:
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? ""
            return .http(status: status, detail: detail)
        }
    }
}
