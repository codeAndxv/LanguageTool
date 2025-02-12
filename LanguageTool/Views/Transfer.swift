import SwiftUI
import AppKit

struct Transfer: View {
    @State private var inputPath: String = "未选择文件"
    @State private var outputPath: String = "未选择保存位置"
    @State private var isInputSelected: Bool = false
    @State private var isOutputSelected: Bool = false
    @State private var conversionResult: String = ""
    @State private var showResult: Bool = false
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                self.inputPath = fileURL.path
                self.isInputSelected = true
            }
        }
    }
    
    private func selectOutputPath() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        
        // 设置默认文件名（使用当前时间）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let defaultFileName = "chinese_keys_\(dateFormatter.string(from: Date())).txt"
        panel.nameFieldStringValue = defaultFileName
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                self.outputPath = fileURL.path
                self.isOutputSelected = true
            }
        }
    }
    
    private func performConversion() {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)) else {
                conversionResult = "错误：文件未找到"
                showResult = true
                return
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                conversionResult = "错误：不是有效的 JSON 格式"
                showResult = true
                return
            }

            var chineseKeys = Set<String>()

            func extractKeys(from object: Any) {
                if let dictionary = object as? [String: Any] {
                    for (key, value) in dictionary {
                        if key.range(of: "\\p{Han}", options: .regularExpression) != nil {
                            chineseKeys.insert(key)
                        }
                        extractKeys(from: value)
                    }
                } else if let array = object as? [Any] {
                    for item in array {
                        extractKeys(from: item)
                    }
                }
            }

            extractKeys(from: jsonObject)
            let keysArray = Array(chineseKeys)

            try keysArray.joined(separator: "\n").write(toFile: outputPath, atomically: true, encoding: .utf8)
            conversionResult = "✅ 成功提取 \(chineseKeys.count) 个中文键并写入文件"
            showResult = true
        } catch {
            conversionResult = "❌ 转换失败：\(error.localizedDescription)"
            showResult = true
        }
    }
    
    private func convertToLocalization() {
        guard let chineseKeys = JsonUtils.extractChineseKeysAsArray(from: inputPath) else {
            conversionResult = "❌ 提取中文键失败"
            showResult = true
            return
        }
        
        if let jsonData = LocalizationJSONGenerator.generateJSON(for: chineseKeys) {
            do {
                try jsonData.write(to: URL(fileURLWithPath: outputPath))
                conversionResult = "✅ 成功生成本地化 JSON 文件，包含 \(chineseKeys.count) 个键"
                showResult = true
            } catch {
                conversionResult = "❌ 写入文件失败: \(error.localizedDescription)"
                showResult = true
            }
        } else {
            conversionResult = "❌ 生成 JSON 失败"
            showResult = true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 输入文件选择
            VStack(alignment: .leading, spacing: 10) {
                Button("选择读取文件") {
                    selectInputFile()
                }
                Text(inputPath)
                    .foregroundColor(.gray)
                    .font(.system(.body, design: .monospaced))
            }
            
            // 输出路径选择
            VStack(alignment: .leading, spacing: 10) {
                Button("选择保存路径") {
                    selectOutputPath()
                }
                Text(outputPath)
                    .foregroundColor(.gray)
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack(spacing: 20) {
                Button("提取中文键") {
                    performConversion()
                }
                .disabled(!isInputSelected || !isOutputSelected)
                .buttonStyle(.borderedProminent)
                
                Button("生成本地化 JSON") {
                    convertToLocalization()
                }
                .disabled(!isInputSelected || !isOutputSelected)
                .buttonStyle(.borderedProminent)
            }
            
            // 显示转换结果
            if showResult {
                Text(conversionResult)
                    .foregroundColor(conversionResult.hasPrefix("✅") ? .green : .red)
                    .font(.system(.body, design: .rounded))
                    .padding(.vertical)
            }
        }
        .padding()
        .frame(maxWidth: 600)
    }
}
