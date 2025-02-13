import Foundation

struct Message: Codable {
    let role: String
    let content: String
}

class AIService {
    static let shared = AIService()
    private let apiKey = "sk-8b26fcbf97a14d34875d3e983a3f41ea"
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"

    enum AIError: Error, LocalizedError { // 遵循 LocalizedError 协议
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case jsonError(Error)

        var errorDescription: String? { // 实现 errorDescription
            switch self {
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
}
