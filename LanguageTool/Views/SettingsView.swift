import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"  // 默认为英语
    
    private let supportedLanguages = [
        ("en", "English"),
        ("zh-Hans", "简体中文")
    ]
    
    // 添加语言切换通知
    @State private var languageChanged = false
    
    var body: some View {
        Form {
            Section(header: Text("API 设置".localized)) {
                // AI 服务选择
                Picker("翻译服务".localized, selection: $selectedService) {
                    ForEach(AIServiceType.allCases, id: \.self) { service in
                        Text(service.rawValue).tag(service)
                    }
                }
                .pickerStyle(.segmented)
                
                // DeepSeek API Key
                if selectedService == .deepseek {
                    SecureField("DeepSeek API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Gemini API Key
                if selectedService == .gemini {
                    SecureField("Gemini API Key", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Section(header: Text("语言设置".localized)) {
                Picker("界面语言".localized, selection: $appLanguage) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .onChange(of: appLanguage) { oldValue, newValue in
                    // 更新语言设置
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()
                    
                    // 发送语言变更通知
                    NotificationCenter.default.post(name: .languageChanged, object: nil)
                    languageChanged.toggle()
                }
            }
            
            Section("其他设置".localized) {
                Text("更多设置项开发中...".localized)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 20)
        .frame(width: 400)
        .frame(minHeight: 200)
        .id(languageChanged) // 强制视图刷新
    }
}

// 添加语言变更通知名称
extension Notification.Name {
    static let languageChanged = Notification.Name("com.app.languageChanged")
} 
