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
    
    // 根据选择的服务返回对应的 baseURL
    private var baseURL: String {
        switch selectedService {
        case .deepseek:
            return "https://api.deepseek.com/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
        }
    }
    
    // 根据选择的服务构建请求体
    private func buildRequestBody(messages: [Message]) -> [String: Any] {
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
    private func parseResponse(data: Data) throws -> String {
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
    
    func sendMessage(messages: [Message], completion: @escaping (Result<String, AIError>) -> Void) {
        guard let url = URL(string: baseURL) else {
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
        
        let body = buildRequestBody(messages: messages)
        
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
                let content = try self.parseResponse(data: data)
                completion(.success(content))
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
    func batchTranslate(
        texts: [String],
        to targetLanguage: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [String] {
        let batchSize = 10  // 每批处理10个文本
        var allTranslations: [String] = []
        
        // 将文本分批处理
        for batchIndex in stride(from: 0, to: texts.count, by: batchSize) {
            let endIndex = min(batchIndex + batchSize, texts.count)
            let batchTexts = Array(texts[batchIndex..<endIndex])
            
            // 更新进度
            let progress = Double(batchIndex) / Double(texts.count)
            DispatchQueue.main.async {
                progressHandler?(progress)
            }
            
            // 处理当前批次
            let separator = "|||"
            let combinedText = batchTexts.joined(separator: separator)
            
            // 根据不同的 AI 服务生成不同的翻译提示
            let prompt: String
            switch selectedService {
            case .deepseek:
                prompt = """
                请将以下文本翻译成\(targetLanguage)。
                每个文本之间使用 ||| 分隔，请保持这个分隔符，只返回翻译结果：
                
                \(combinedText)
                """
            case .gemini:
                prompt = """
                Translate the following texts to \(targetLanguage).
                Each text is separated by |||. Keep the separators and only return the translations:
                
                \(combinedText)
                """
            }
            
            let messages: [Message]
            switch selectedService {
            case .deepseek:
                messages = [Message(role: "system", content: prompt)]
            case .gemini:
                messages = [Message(role: "user", content: prompt)]
            }
            
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
            guard translations.count == batchTexts.count else {
                throw AIError.invalidResponse
            }
            
            // 添加到结果中
            allTranslations.append(contentsOf: translations)
            
            // 添加延迟以避免触发速率限制
            if endIndex < texts.count {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1秒延迟
            }
        }
        
        // 完成时更新进度为100%
        DispatchQueue.main.async {
            progressHandler?(1.0)
        }
        
        return allTranslations
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
