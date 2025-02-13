import SwiftUI
import AppKit

struct Transfer: View {
    @State private var inputPath: String = "未选择文件"
    @State private var outputPath: String = "未选择保存位置"
    @State private var isInputSelected: Bool = false
    @State private var isOutputSelected: Bool = false
    @State private var conversionResult: String = ""
    @State private var showResult: Bool = false
    @State private var selectedLanguages: Set<Language> = [Language.supportedLanguages[0]] // 默认选中简体中文
    @State private var isLoading: Bool = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
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
            isLoading = true // 开始加载
            showResult = false // 清除之前的结果
            
            let result = await JsonUtils.convertToLocalizationFile(
                from: inputPath,
                to: outputPath,
                languages: Array(selectedLanguages).map { $0.code }
            )
            
            DispatchQueue.main.async {
                isLoading = false // 结束加载
                conversionResult = result.message
                showResult = true
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 主要内容
            VStack(spacing: 20) {
                // 文件选择部分
                VStack(alignment: .leading, spacing: 10) {
                    Button("选择读取文件") {
                        selectInputFile()
                    }
                    Text(inputPath)
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Button("选择保存路径") {
                        selectOutputPath()
                    }
                    Text(outputPath)
                        .foregroundColor(.gray)
                        .font(.system(.body, design: .monospaced))
                }
                
                // 语言选择部分
                VStack(alignment: .leading, spacing: 10) {
                    Text("选择目标语言")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Language.supportedLanguages) { language in
                                LanguageToggle(language: language, isSelected: selectedLanguages.contains(language))
                                    .onTapGesture {
                                        if selectedLanguages.contains(language) {
                                            if selectedLanguages.count > 1 { // 确保至少选中一种语言
                                                selectedLanguages.remove(language)
                                            }
                                        } else {
                                            selectedLanguages.insert(language)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 转换按钮
                Button("开始转换") {
                    convertToLocalization()
                }
                .disabled(!isInputSelected || !isOutputSelected || selectedLanguages.isEmpty || isLoading)
                .buttonStyle(.borderedProminent)
                
                if showResult {
                    Text(conversionResult)
                        .foregroundColor(conversionResult.hasPrefix("✅") ? .green : .red)
                        .font(.system(.body, design: .rounded))
                        .padding(.vertical)
                }
            }
            .padding()
            .frame(maxWidth: 600)
            .blur(radius: isLoading ? 3 : 0) // 在加载时模糊背景
            .overlay {
                if isLoading {
                    // 加载指示器
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在翻译中...")
                            .font(.headline)
                        Text("请耐心等待，这可能需要一些时间")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.background)
                            .shadow(radius: 20)
                    }
                }
            }
        }
        // 在加载时禁用所有交互
        .allowsHitTesting(!isLoading)
    }
}

// 语言选择切换组件
struct LanguageToggle: View {
    let language: Language
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
            VStack(alignment: .leading) {
                Text(language.localizedName)
                    .font(.system(.body, design: .rounded))
                Text(language.code)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}
