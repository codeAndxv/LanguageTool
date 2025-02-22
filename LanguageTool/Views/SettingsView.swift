import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedAIService") private var selectedService: AIServiceType = .deepseek
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    
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
