import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "en"  // 默认为英语
    
    private let supportedLanguages = [
        ("en", "English".localized),
        ("zh-Hans", "Simplified Chinese".localized),
        ("zh-Hant", "Traditional Chinese".localized),
        ("ja", "Japanese".localized),
        ("ko", "Korean".localized)
    ]
    
    // 添加语言切换通知
    @State private var languageChanged = false
    
    var body: some View {
        Form {
            Section(header: Text("API Settings".localized)) {
                // AI 服务选择
                Picker("Translation Service".localized, selection: $selectedService) {
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
            
            Section(header: Text("Language Settings".localized)) {
                Picker("Interface Language".localized, selection: $appLanguage) {
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
            
            Section("Other Settings".localized) {
                Text("More Settings Under Development...".localized)
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
