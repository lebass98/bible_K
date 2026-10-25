import CryptoKit
import Foundation
import Security

/// 구글 Cloud Text-to-Speech로 읽어 주기
/// 사용자의 API 키가 필요함 (키체인에 저장). 만든 음성은 캐시에 남겨 같은 절을 다시 요청하지 않음
enum GoogleTTS {
    struct Voice: Identifiable, Hashable {
        let name: String        // ko-KR-Neural2-A
        let gender: String      // FEMALE / MALE
        var id: String { name }

        /// "Neural2-A · 여성"
        var label: String {
            let parts = name.split(separator: "-")
            let short = parts.count > 2 ? parts.dropFirst(2).joined(separator: "-") : name
            let genderName = gender == "FEMALE" ? "여성" : gender == "MALE" ? "남성" : "중성"
            return "\(short) · \(genderName)"
        }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let base = "https://texttospeech.googleapis.com/v1"

    /// "ko" → "ko-KR"
    static func languageCode(_ language: String) -> String {
        switch language {
        case "ko": return "ko-KR"
        case "en": return "en-US"
        default: return language.contains("-") ? language : language
        }
    }

    // MARK: 음성 만들기

    static func synthesize(text: String, language: String, voice: String, rate: Double) async throws -> Data {
        let code = languageCode(language)
        let cacheFile = cacheURL(for: "\(code)|\(voice)|\(String(format: "%.2f", rate))|\(text)")
        if let cached = try? Data(contentsOf: cacheFile) { return cached }

        guard let key = APIKeyStore.load(), !key.isEmpty else { throw Failure(message: "구글 API 키가 없어요. 설정에서 넣어 주세요.") }
        var voiceObject: [String: Any] = ["languageCode": code]
        if !voice.isEmpty { voiceObject["name"] = voice }
        let body: [String: Any] = [
            "input": ["text": text],
            "voice": voiceObject,
            "audioConfig": ["audioEncoding": "MP3", "speakingRate": rate],
        ]
        var request = URLRequest(url: URL(string: "\(base)/text:synthesize")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let content = json["audioContent"] as? String,
              let audio = Data(base64Encoded: content) else {
            throw Failure(message: errorMessage(json, status: (response as? HTTPURLResponse)?.statusCode))
        }
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try? audio.write(to: cacheFile)
        return audio
    }

    // MARK: 목소리 목록

    static func voices(language: String) async throws -> [Voice] {
        guard let key = APIKeyStore.load(), !key.isEmpty else { throw Failure(message: "구글 API 키가 없어요.") }
        var components = URLComponents(string: "\(base)/voices")!
        components.queryItems = [URLQueryItem(name: "languageCode", value: languageCode(language))]
        var request = URLRequest(url: components.url!)
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(message: errorMessage(json, status: (response as? HTTPURLResponse)?.statusCode))
        }
        let list = json["voices"] as? [[String: Any]] ?? []
        return list.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return Voice(name: name, gender: item["ssmlGender"] as? String ?? "")
        }
        .sorted { $0.name < $1.name }
    }

    private static func errorMessage(_ json: [String: Any], status: Int?) -> String {
        let error = json["error"] as? [String: Any]
        let message = error?["message"] as? String ?? "알 수 없는 오류"
        switch status {
        case 400 where message.contains("API key"): return "API 키가 올바르지 않아요."
        case 403: return "권한이 없어요. Google Cloud에서 Text-to-Speech API를 켰는지, 결제 계정이 연결됐는지 확인하세요. (\(message))"
        case 429: return "요청이 너무 많아요. 잠시 뒤에 다시 해 보세요."
        default: return "\(message) (\(status ?? 0))"
        }
    }

    // MARK: 캐시

    static let cacheFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("YeollinBible/tts", isDirectory: true)

    private static func cacheURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheFolder.appendingPathComponent("\(hash).mp3")
    }

    static func cacheSize() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheFolder)
    }
}

/// API 키는 키체인에 저장 (설정 파일에 그대로 남기지 않음)
enum APIKeyStore {
    private static let service = "com.local.YeollinBible.google-tts"
    private static let account = "api-key"
    /// 키체인을 매번 열지 않게 한 번 읽은 값을 기억
    private static var memory: String??

    static func load() -> String? {
        if let memory { return memory }
        let value = readKeychain()
        memory = .some(value)
        return value
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "열린성경 – 구글 TTS API 키",
            kSecValueData as String: Data(key.utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        memory = .some(status == errSecSuccess ? key : nil)
        if status != errSecSuccess { DebugLog.write("API 키 저장 실패: \(status)") }
        return status == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        memory = .some(nil)
    }

    static var hasKey: Bool { !(load() ?? "").isEmpty }
}
