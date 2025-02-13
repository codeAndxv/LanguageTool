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
        let defaultFileName = "Localizable_\(dateFormatter.string(from: Date())).xcstrings" //Localizable.xcstrings
        panel.nameFieldStringValue = defaultFileName
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                self.outputPath = fileURL.path
                self.isOutputSelected = true
            }
        }
    }
    
    private func performConversion() {
        let result = JsonUtils.extractChineseKeysToFile(from: inputPath, to: outputPath)
        conversionResult = result.message
        showResult = true
    }
    
    private func convertToLocalization() {
        Task {
            let result = await JsonUtils.convertToLocalizationFile(from: inputPath, to: outputPath)
            DispatchQueue.main.async {
                conversionResult = result.message
                showResult = true
            }
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
