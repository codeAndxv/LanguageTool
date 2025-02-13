import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var isEditingAPIKey = false
    @State private var temporaryAPIKey = ""
    
    var body: some View {
        Form {
            Section("API 设置") {
                VStack(alignment: .leading, spacing: 8) {
                    if isEditingAPIKey {
                        TextField("请输入 API Key", text: $temporaryAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 300)
                        
                        HStack(spacing: 8) {
                            Button("保存") {
                                settings.apiKey = temporaryAPIKey
                                isEditingAPIKey = false
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("取消") {
                                temporaryAPIKey = settings.apiKey
                                isEditingAPIKey = false
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        HStack(spacing: 12) {
                            if settings.apiKey.isEmpty {
                                Text("未设置")
                                    .foregroundColor(.red)
                            } else {
                                Text(settings.apiKey.prefix(6) + "..." + settings.apiKey.suffix(6))
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Button("编辑") {
                                temporaryAPIKey = settings.apiKey
                                isEditingAPIKey = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Text("API Key 用于访问 AI 翻译服务，请妥善保管")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
