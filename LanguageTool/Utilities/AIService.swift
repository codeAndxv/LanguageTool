import Foundation
import SwiftUI

struct Message: Codable {
    let role: String
    let content: String
}

class AIService {
    static let shared = AIService()
    
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    
    // 添加批处理大小属性
    private let batchSize = 10  // 每批处理10个文本
    
    private var apiKey: String {
        AppSettings.shared.apiKey
    }
    
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"

    enum AIError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case jsonError(Error)
        case invalidConfiguration(String)
        
        var localizedDescription: String {
            switch self {
            case .invalidConfiguration(let message):
                return "⚠️ 配置错误: \(message)"
            case .invalidURL:
                return "❌ URL 创建失败"
            case .networkError(let error):
                return "❌ 网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "⚠️ 无效的响应"
            case .jsonError(let error):
                return "❌ JSON 错误: \(error.localizedDescription)"
            }
        }
    }
    
    func sendMessage(messages: [Message], completion: @escaping (Result<String, AIError>) -> Void) {
        // 检查 API Key
        guard !apiKey.isEmpty else {
            completion(.failure(.invalidConfiguration("未设置 API Key")))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        print("📝 准备发送的消息内容: \(messages)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.jsonError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON 序列化失败"])))) // 更详细的错误信息
            return
        }
        
        request.httpBody = jsonData
        print("📤 发送请求体: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 网络错误: \(error.localizedDescription)")
                completion(.failure(.networkError(error)))
                return
            }
            
//            if let httpResponse = response as? HTTPURLResponse {
//                print("📡 HTTP 状态码: \(httpResponse.statusCode)")
//                print("📋 响应头: \(httpResponse.allHeaderFields)")
//            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { // 检查HTTP状态码
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print("📥 收到响应数据: \(String(data: data, encoding: .utf8) ?? "")")
            do {
                let json = try JSONSerialization.jsonObject(with: data)
                print("✅ 解析后的 JSON: \(json)")
            } catch {
                print("❌ JSON 解析错误: \(error.localizedDescription)")
            }
            
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonDict["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async { // 回到主线程
                        completion(.success(content))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.jsonError(error)))
            }
        }
        
        task.resume()
    }
    
    func translate(text: String, to targetLanguage: String) async throws -> String {
        switch selectedService {
        case .deepseek:
            return try await translateWithDeepseek(text: text, to: targetLanguage)
        case .gemini:
            return try await translateWithGemini(text: text, to: targetLanguage)
        }
    }
    
    /// 批量翻译文本
    func batchTranslate(texts: [String], to targetLanguage: String) async throws -> [String] {
        var translatedTexts: [String] = []
        
        // 将数组分批处理
        let batches = stride(from: 0, to: texts.count, by: batchSize).map {
            Array(texts[$0..<min($0 + batchSize, texts.count)])
        }
        
        // 每次处理一批文本
        for batch in batches {
            let prompt = generateTranslationPrompt(texts: batch, targetLanguage: targetLanguage)
            let messages = [Message(role: "user", content: prompt)]
            
            // 使用 async/await 方式调用
            let response = try await withCheckedThrowingContinuation { continuation in
                sendMessage(messages: messages) { result in
                    switch result {
                    case .success(let content):
                        continuation.resume(returning: content)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            let translations = parseTranslations(from: response)
            
            // 清理每个翻译文本
            let cleanedTranslations = translations.map { text -> String in
                return text
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
            }
            
            translatedTexts.append(contentsOf: cleanedTranslations)
        }
        
        return translatedTexts
    }
    
    /// 生成翻译提示
    private func generateTranslationPrompt(texts: [String], targetLanguage: String) -> String {
        let numberedTexts = texts.enumerated().map { index, text in
            "\(index + 1). \(text)"
        }.joined(separator: "\n")
        
        return """
        请将以下文本翻译成\(targetLanguage)语言。
        只需返回翻译结果，每行一个翻译，保持原有的编号顺序：
        
        \(numberedTexts)
        """
    }
    
    /// 解析翻译结果
    private func parseTranslations(from response: String) -> [String] {
        // 移除可能的序号和额外标记
        let lines = response
            .components(separatedBy: .newlines)
            .map { line -> String in
                var cleaned = line
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
                
                // 如果翻译文本被引号包围，移除引号
                if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
                    cleaned = String(cleaned.dropFirst().dropLast())
                }
                
                return cleaned
            }
            .filter { !$0.isEmpty }
        
        return lines
    }
    
    // 原有的 DeepSeek 翻译方法
    private func translateWithDeepseek(text: String, to targetLanguage: String) async throws -> String {
        let message = Message(role: "system", 
                            content: "将以下文本翻译成\(targetLanguage)语言，只需要返回翻译结果，不需要任何解释：\n\(text)")
        
        return try await withCheckedThrowingContinuation { continuation in
            sendMessage(messages: [message]) { result in
                switch result {
                case .success(let translation):
                    continuation.resume(returning: translation.trimmingCharacters(in: .whitespacesAndNewlines))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 新增的 Gemini 翻译方法
    private func translateWithGemini(text: String, to targetLanguage: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(geminiApiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let prompt = "Translate the following text to \(targetLanguage). Only return the translation, no explanations: \(text)"
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = jsonResponse["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let translation = firstPart["text"] as? String {
            return translation
        }
        
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
    
    /// 测试 Gemini API 连接
    func testGemini() async throws {
        let apiKey = "YOUR_API_KEY"  // 替换为实际的 API key
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        let url = URL(string: urlString)!
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Hello, this is a test message."
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("开始测试 Gemini API...")
        print("请求 URL: \(urlString)")
        print("请求体: \(requestBody)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("响应状态码: \(httpResponse.statusCode)")
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("响应数据: \(jsonResponse)")
            }
            
            print("API 测试成功")
        } catch {
            print("API 测试失败: \(error.localizedDescription)")
            throw error
        }
    }
    
}
