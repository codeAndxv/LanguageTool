import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
        }
    }
    
    private init() {
        // 从 UserDefaults 读取存储的设置
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }
} 