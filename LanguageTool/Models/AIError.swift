import Foundation

enum AIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case jsonError(Error)
    case apiError(String)
    case rateLimitExceeded
    case unauthorized
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL".localized
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)".localized
        case .invalidResponse:
            return "Invalid Response from Server".localized
        case .jsonError(let error):
            return "JSON Error: \(error.localizedDescription)".localized
        case .apiError(let message):
            return "API Error: \(message)".localized
        case .rateLimitExceeded:
            return "Rate Limit Exceeded".localized
        case .unauthorized:
            return "Invalid API Key".localized
        case .invalidConfiguration(let message):
            return "⚠️ 配置错误: \(message)"
        }
    }
} 
