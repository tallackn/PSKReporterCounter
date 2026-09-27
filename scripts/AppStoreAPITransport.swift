import CryptoKit
import Foundation

// The private key and signed token stay inside this process. The Python
// release tool receives only the HTTP status and the API response body.
private struct Credentials: Decodable {
    let issuerID: String
    let keyID: String
    let privateKeyPath: String
}

private struct Input: Decodable {
    let credentialsFile: String
    let method: String
    let url: String
    let body: String?
}

private struct Output: Encodable {
    let status: Int
    let body: String
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private func encoded(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

@main
private enum AppStoreAPITransport {
    static func main() async {
        do {
            let input = try JSONDecoder().decode(Input.self, from: FileHandle.standardInput.readDataToEndOfFile())
            guard let url = URL(string: input.url), url.scheme == "https",
                  url.host == "api.appstoreconnect.apple.com", url.port == nil,
                  url.user == nil, url.password == nil, url.path.hasPrefix("/v1/"),
                  ["GET", "POST", "PATCH"].contains(input.method) else {
                throw NSError(domain: "ReleaseTransport", code: 1)
            }
            let credentials = try JSONDecoder().decode(Credentials.self,
                from: Data(contentsOf: URL(fileURLWithPath: input.credentialsFile)))
            let key = try P256.Signing.PrivateKey(pemRepresentation:
                String(contentsOfFile: credentials.privateKeyPath, encoding: .utf8))
            let now = Int(Date().timeIntervalSince1970)
            let header = try JSONSerialization.data(withJSONObject:
                ["alg": "ES256", "kid": credentials.keyID, "typ": "JWT"])
            let claims = try JSONSerialization.data(withJSONObject:
                ["iss": credentials.issuerID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"])
            let unsigned = "\(encoded(header)).\(encoded(claims))"
            let signature = try key.signature(for: Data(unsigned.utf8)).rawRepresentation
            var request = URLRequest(url: url)
            request.httpMethod = input.method
            request.setValue("Bearer \(unsigned).\(encoded(signature))", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body = input.body {
                request.httpBody = Data(body.utf8)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 45
            configuration.urlCache = nil
            let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            let output = Output(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
            FileHandle.standardOutput.write(try JSONEncoder().encode(output))
        } catch {
            // Do not print request objects, credentials, keys or tokens.
            FileHandle.standardError.write(Data("App Store API transport failed. Check the local credential file, key permissions and network connection.\n".utf8))
            exit(1)
        }
    }
}
