import Foundation
import SwiftUI

struct Message: Codable {
    let role: String
    let content: String
}

// 定义一个协议，抽象出公共逻辑
protocol AIServiceProtocol {
    var baseURL: String { get }
    func buildRequestBody(messages: [Message]) -> [String: Any]
    func parseResponse(data: Data) throws -> String
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
    
    // 根据选择的服务返回对应的 baseURL
    internal var baseURL: String {
        switch selectedService {
        case .deepseek:
            return "https://api.deepseek.com/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
        }
    }
    
    // 根据选择的服务构建请求体
    internal func buildRequestBody(messages: [Message]) -> [String: Any] {
        switch selectedService {
        case .deepseek:
            return [
                "model": "deepseek-chat",
                "messages": messages.map { ["role": $0.role, "content": $0.content] }
            ]
        case .gemini:
            return [
                "contents": [
                    [
                        "parts": [
                            [
                                "text": messages.last?.content ?? ""
                            ]
                        ]
                    ]
                ]
            ]
        }
    }
    
    // 根据选择的服务解析响应
    internal func parseResponse(data: Data) throws -> String {
        switch selectedService {
        case .deepseek:
            let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // 检查错误响应
            if let error = jsonDict?["error"] as? [String: Any],
               let message = error["message"] as? String {
                if message.contains("rate limit") {
                    throw AIError.rateLimitExceeded
                } else if message.contains("invalid api key") {
                    throw AIError.unauthorized
                }
                throw AIError.apiError(message)
            }
            
            // 解析正常响应
            if let choices = jsonDict?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
            throw AIError.invalidResponse
            
        case .gemini:
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // 检查错误响应
            if let error = jsonResponse?["error"] as? [String: Any],
               let message = error["message"] as? String {
                if message.contains("quota") {
                    throw AIError.rateLimitExceeded
                } else if message.contains("API key") {
                    throw AIError.unauthorized
                }
                throw AIError.apiError(message)
            }
            
            // 解析正常响应
            if let candidates = jsonResponse?["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                return text
            }
            throw AIError.invalidResponse
        }
    }
    
    // 修改 sendMessage 方法以使用协议
    func sendMessage(messages: [Message], completion: @escaping (Result<String, AIError>) -> Void) {
        // 检查 API Key
        let apiKeyToUse: String
        switch selectedService {
        case .deepseek:
            apiKeyToUse = apiKey  // 使用 DeepSeek 的 API Key
        case .gemini:
            apiKeyToUse = geminiApiKey  // 使用 Gemini 的 API Key
        }
        
        guard !apiKeyToUse.isEmpty else {
            completion(.failure(.invalidConfiguration("未设置 API Key")))
            return
        }
        
        print("🔑 使用的 API Key: \(apiKeyToUse)")  // 打印 API Key（注意：在生产环境中请勿打印敏感信息）
        
        // 根据选择的服务设置 URL
        let urlString: String
        switch selectedService {
        case .deepseek:
            urlString = baseURL
        case .gemini:
            // 将 API Key 添加到 URL 查询参数中
            urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKeyToUse)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        print("📝 准备发送的消息内容: \(messages)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKeyToUse)", forHTTPHeaderField: "Authorization")
        
        // 根据服务类型构建请求体
        let body: [String: Any]
        switch selectedService {
        case .deepseek:
            body = [
                "model": "deepseek-chat",
                "messages": messages.map { ["role": $0.role, "content": $0.content] }
            ]
        case .gemini:
            body = [
                "contents": [
                    [
                        "parts": [
                            [
                                "text": messages.last?.content ?? ""
                            ]
                        ]
                    ]
                ]
            ]
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.jsonError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON 序列化失败"]))))
            return
        }
        
        request.httpBody = jsonData
        print("📤 发送请求体: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        // 打印完整的请求 URL
        print("🔗 请求 URL: \(url.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 网络错误: \(error.localizedDescription)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print("📡 HTTP 状态码: \(httpResponse.statusCode)")  // 打印状态码
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ 无效的响应状态码: \(httpResponse.statusCode)")
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            print("📥 收到响应数据: \(String(data: data, encoding: .utf8) ?? "")")
            
            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("✅ 解析后的 JSON: \(String(describing: jsonDict))")
                
                if let candidates = jsonDict?["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let responseText = firstPart["text"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(responseText))
                    }
                } else {
                    print("❌ 响应格式不正确: \(String(describing: jsonDict))")
                    completion(.failure(.invalidResponse))
                }
            } catch {
                print("❌ JSON 解析错误: \(error.localizedDescription)")
                completion(.failure(.jsonError(error)))
            }
        }
        
        task.resume()
    }
    
    //未使用？
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
        // 将所有文本合并成一个字符串，使用特殊分隔符
        let separator = "|||"
        let combinedText = texts.joined(separator: separator)
        
        // 生成翻译提示
        let prompt = """
        请将以下文本翻译成\(targetLanguage)。
        每个文本之间使用 ||| 分隔，请保持这个分隔符，只返回翻译结果：
        
        \(combinedText)
        """
        
        let messages = [Message(role: "user", content: prompt)]
        
        // 发送翻译请求
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
        
        // 清理并分割翻译结果
        let cleanedResponse = response
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        
        let translations = cleanedResponse.components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 确保翻译结果数量与原文本数量匹配
        guard translations.count == texts.count else {
            throw AIError.invalidResponse
        }
        
        return translations
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
        let apiKey = "AIzaSyAsneGHF01bSpb1uxAYpnxFMW3iLI0oC5w"  // 替换为实际的 API key
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        let url = URL(string: urlString)!
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "请将以下文本翻译成en-IN。\n每个文本之间使用 ||| 分隔，请保持这个分隔符，只返回翻译结果：\n\n左侧|||首页|||更改|||右侧|||统计|||总计|||统计图表"
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


// 扩展 AIService 以实现协议
extension AIService: AIServiceProtocol {
    func sendMessage<T: AIServiceProtocol>(messages: [Message], service: T, completion: @escaping (Result<String, AIError>) -> Void) {
        guard let url = URL(string: service.baseURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 根据服务类型设置不同的认证头
        switch selectedService {
        case .deepseek:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .gemini:
            // Gemini API key 直接附加在 URL 中，不需要认证头
            break
        }
        
        let body = service.buildRequestBody(messages: messages)
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.jsonError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON serialization failed"]))))
            return
        }
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let content = try service.parseResponse(data: data)
                completion(.success(content))
            } catch {
                completion(.failure(.jsonError(error)))
            }
        }
        
        task.resume()
    }
}

// DeepSeek 服务实现
struct DeepSeekService: AIServiceProtocol {
    var baseURL: String {
        return "https://api.deepseek.com/v1/chat/completions"
    }
    
    func buildRequestBody(messages: [Message]) -> [String: Any] {
        return [
            "model": "deepseek-chat",
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
    }
    
    func parseResponse(data: Data) throws -> String {
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // 检查错误响应
        if let error = jsonDict?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("rate limit") {
                throw AIError.rateLimitExceeded
            } else if message.contains("invalid api key") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }
        
        // 解析正常响应
        if let choices = jsonDict?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw AIError.invalidResponse
    }
}

// Gemini 服务实现
struct GeminiService: AIServiceProtocol {
    var baseURL: String {
        return "https://generativelanguage.googleapis.com/v1beta/gemini-2.0-flash:generateContent"
    }
    
    func buildRequestBody(messages: [Message]) -> [String: Any] {
        return [
            "contents": [
                [
                    "parts": [
                        [
                            "text": messages.last?.content ?? ""
                        ]
                    ]
                ]
            ]
        ]
    }
    
    func parseResponse(data: Data) throws -> String {
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // 检查错误响应
        if let error = jsonResponse?["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.contains("quota") {
                throw AIError.rateLimitExceeded
            } else if message.contains("API key") {
                throw AIError.unauthorized
            }
            throw AIError.apiError(message)
        }
        
        // 解析正常响应
        if let candidates = jsonResponse?["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text
        }
        throw AIError.invalidResponse
    }
}
