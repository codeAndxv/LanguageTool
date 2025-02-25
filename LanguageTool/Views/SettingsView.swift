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
    
    var body: some View {
        Form {
            Section(header: Text("API 设置")) {
                // AI 服务选择
                Picker("翻译服务", selection: $selectedService) {
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
            
            Section(header: Text("语言设置")) {
                // 语言选择
                Picker("Interface Language", selection: $appLanguage) {
                    ForEach(supportedLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
                .onChange(of: appLanguage) { oldValue, newValue in
                    // 提示用户需要重启应用
                    let alert = NSAlert()
                    alert.messageText = String(localized: "Language Setting Changed")
                    alert.informativeText = String(localized: "Please restart the app to apply the new language setting")
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: String(localized: "OK"))
                    alert.runModal()
                }
            }
            
            Section("其他设置") {
                Text("更多设置项开发中...")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 20)
        .frame(width: 400)
        .frame(minHeight: 200)
    }
} 
