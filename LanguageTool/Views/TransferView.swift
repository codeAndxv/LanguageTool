import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TransferView: View {
    @State private var inputPath: String = "未选择文件"
    @State private var outputPath: String = "未选择保存位置"
    @State private var isInputSelected: Bool = false
    @State private var isOutputSelected: Bool = false
    @State private var conversionResult: String = ""
    @State private var showResult: Bool = false
    @State private var selectedLanguages: Set<Language> = [Language.supportedLanguages[0]] // 默认选中简体中文
    @State private var isLoading: Bool = false
    @State private var showSuccessActions: Bool = false
    @State private var outputFormat: LocalizationFormat = .xcstrings
    @State private var hasDirectoryPermission: Bool = false // 添加权限状态追踪
    
    enum LocalizationFormat {
        case xcstrings
        case strings
        
        var description: String {
            switch self {
            case .xcstrings: return "Xcode Strings Catalog (.xcstrings)"
            case .strings: return "Strings File (.strings)"
            }
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        // 支持 .json、.xcstrings 和 .strings 文件
        let xcstringsType = UTType("com.apple.xcode.strings-text")! // Xcode 的 .xcstrings 类型
        let stringsType = UTType.propertyList // .strings 文件实际上是属性列表类型
        panel.allowedContentTypes = [.json, xcstringsType, stringsType]
        
        // 设置文件类型描述
        panel.title = "选择本地化文件"
        panel.message = "请选择 JSON、Localizable.xcstrings 或 Localizable.strings 文件"
        
        // 设置初始目录为文稿
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            panel.directoryURL = documentsURL
        }
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                self.inputPath = fileURL.path
                self.isInputSelected = true
            }
        }
    }
    
    private func selectOutputPath() {
        let panel = NSSavePanel()
        let xcstringsType = UTType("com.apple.xcode.strings-text")!
        let stringsType = UTType.propertyList
        
        // 根据选择的输出格式设置允许的文件类型
        panel.allowedContentTypes = [outputFormat == .xcstrings ? xcstringsType : stringsType]
        
        // 设置默认文件名（使用当前时间）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        
        // 根据选择的输出格式设置默认文件名和扩展名
        let timestamp = dateFormatter.string(from: Date())
        let fileExtension = outputFormat == .xcstrings ? "xcstrings" : "strings"
        let defaultFileName = "Localizable_\(timestamp).\(fileExtension)"
        panel.nameFieldStringValue = defaultFileName
        
        // 允许创建目录
        panel.canCreateDirectories = true
        
        // 设置面板标题和提示
        panel.title = "保存本地化文件"
        panel.message = outputFormat == .xcstrings ? 
            "选择保存 .xcstrings 文件的位置" : 
            "选择保存 .strings 文件的位置（将在选择位置创建语言子目录）"
        
        // 设置初始目录为文稿
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            panel.directoryURL = documentsURL
        }
        
        panel.begin { [self] response in
            if response == .OK, let fileURL = panel.url {
                // 如果是 .strings 格式，检查是否已有权限
                if outputFormat == .strings && !hasDirectoryPermission {
                    DispatchQueue.main.async {
                        self.conversionResult = "❌ 未获得目录访问权限，请先选择 .strings 格式获取权限"
                        self.showResult = true
                        self.isOutputSelected = false
                        self.outputPath = "未选择保存位置"
                    }
                    return
                }
                
                self.outputPath = fileURL.path
                self.isOutputSelected = true
            }
        }
    }
    
    private func requestDirectoryAccess(at path: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要访问权限"
                alert.informativeText = "Language Tool 需要访问系统目录来创建本地化文件。请在接下来的对话框中选择要保存的位置。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "选择位置")
                alert.addButton(withTitle: "取消")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.message = "请选择要保存本地化文件的目录"
                    panel.prompt = "选择"
                    
                    // 尝试使用传入的路径作为初始目录
                    panel.directoryURL = URL(fileURLWithPath: path)
                    
                    panel.begin { response in
                        if response == .OK, let selectedURL = panel.url {
                            // 用户选择了目录，检查是否有写入权限
                            let hasAccess = FileManager.default.isWritableFile(atPath: selectedURL.path)
                            continuation.resume(returning: hasAccess)
                        } else {
                            continuation.resume(returning: false)
                        }
                    }
                } else {
                    continuation.resume(returning: false)
                }
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
            isLoading = true
            showResult = false
            showSuccessActions = false
            
            do {
                switch (inputPath as NSString).pathExtension.lowercased() {
                case "strings":
                    let parseResult = StringsFileHandler.readStringsFile(at: inputPath)
                    switch parseResult {
                    case .success(let translations):
                        if outputFormat == .xcstrings {
                            // 转换为 .xcstrings
                            let result = await StringsFileHandler.convertToXCStrings(
                                translations: translations,
                                languages: Array(selectedLanguages).map { $0.code }
                            )
                            
                            switch result {
                            case .success(let jsonData):
                                try jsonData.write(to: URL(fileURLWithPath: outputPath))
                                DispatchQueue.main.async {
                                    conversionResult = "✅ 转换成功！"
                                    showSuccessActions = true
                                }
                            case .failure(let error):
                                DispatchQueue.main.async {
                                    conversionResult = "❌ 转换失败：\(error.localizedDescription)"
                                }
                            }
                        } else {
                            print("开始生成 .strings 文件...")
                            let baseDir = (outputPath as NSString).deletingLastPathComponent
                            
                            // 直接创建目录和开始转换，因为权限已经在选择路径时获取
                            try FileManager.default.createDirectory(
                                atPath: baseDir,
                                withIntermediateDirectories: true,
                                attributes: nil
                            )
                            
                            // 先创建所有语言目录
                            for language in selectedLanguages {
                                let langDir = (baseDir as NSString).appendingPathComponent("\(language.code).lproj")
                                if !FileManager.default.fileExists(atPath: langDir) {
                                    try FileManager.default.createDirectory(
                                        atPath: langDir,
                                        withIntermediateDirectories: true,
                                        attributes: nil
                                    )
                                }
                            }
                            
                            // 确认目录创建成功后，再开始翻译过程
                            for language in selectedLanguages {
                                print("处理语言: \(language.code)")
                                let langDir = (baseDir as NSString).appendingPathComponent("\(language.code).lproj")
                                let stringsPath = (langDir as NSString).appendingPathComponent("Localizable.strings")
                                
                                if language.code == "zh-Hans" {
                                    print("处理源语言文件...")
                                    let result = StringsFileHandler.generateStringsFile(
                                        translations: translations,
                                        to: stringsPath
                                    )
                                    if case .failure(let error) = result {
                                        throw error
                                    }
                                } else {
                                    print("开始翻译: \(language.code)")
                                    var translatedDict: [String: String] = [:]
                                    for (key, value) in translations {
                                        print("翻译: \(key)")
                                        let translation = try await AIService.shared.translate(
                                            text: value,
                                            to: language.code
                                        )
                                        translatedDict[key] = translation
                                    }
                                    
                                    print("生成翻译文件: \(language.code)")
                                    let result = StringsFileHandler.generateStringsFile(
                                        translations: translatedDict,
                                        to: stringsPath
                                    )
                                    if case .failure(let error) = result {
                                        throw error
                                    }
                                }
                            }
                            
                            print("所有文件生成完成")
                            DispatchQueue.main.async {
                                self.conversionResult = "✅ 转换成功！"
                                self.showSuccessActions = true
                            }
                        }
                    case .failure(let error):
                        print("解析失败: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.conversionResult = "❌ 解析失败：\(error.localizedDescription)"
                        }
                    }
                    
                default:
                    // 处理 JSON 和 xcstrings 文件
                    let result = await JsonUtils.convertToLocalizationFile(
                        from: inputPath,
                        to: outputPath,
                        languages: Array(selectedLanguages).map { $0.code }
                    )
                    
                    DispatchQueue.main.async {
                        conversionResult = result.message
                        showSuccessActions = result.success
                    }
                }
            } catch {
                print("转换过程出错: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.conversionResult = "❌ 转换失败：\(error.localizedDescription)"
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.showResult = true
            }
        }
    }
    
    private func openInFinder() {
        NSWorkspace.shared.selectFile(outputPath, inFileViewerRootedAtPath: "")
    }
    
    private func resetAll() {
        withAnimation(.smooth(duration: 0.3)) {
            // 重置文件路径
            inputPath = "未选择文件"
            outputPath = "未选择保存位置"
            isInputSelected = false
            isOutputSelected = false
            
            // 重置语言选择（只保留简体中文）
            selectedLanguages = [Language.supportedLanguages[0]]
            
            // 重置结果显示
            showResult = false
            conversionResult = ""
            showSuccessActions = false
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 左对齐的内容容器
                    VStack(alignment: .leading, spacing: 20) {
                        // 文件选择部分
                        VStack(alignment: .leading, spacing: 10) {
                            Button("选择读取文件") {
                                selectInputFile()
                            }
                            Text(inputPath)
                                .foregroundColor(.gray)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Button("选择保存路径") {
                                selectOutputPath()
                            }
                            Text(outputPath)
                                .foregroundColor(.gray)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
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
                                                    if selectedLanguages.count > 1 {
                                                        selectedLanguages.remove(language)
                                                    }
                                                } else {
                                                    selectedLanguages.insert(language)
                                                }
                                            }
                                    }
                                }
                            }
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // 输出格式选择部分
                        VStack(alignment: .leading, spacing: 10) {
                            Text("输出格式")
                                .font(.headline)
                            
                            Picker("输出格式", selection: $outputFormat) {
                                Text("Xcode Strings Catalog (.xcstrings)")
                                    .tag(LocalizationFormat.xcstrings)
                                Text("Strings File (.strings)")
                                    .tag(LocalizationFormat.strings)
                            }
                            .pickerStyle(.radioGroup)
                            .onChange(of: outputFormat) { newFormat in
                                if newFormat == .strings {
                                    // 当选择 .strings 格式时，重置输出路径并请求权限
                                    outputPath = "未选择保存位置"
                                    isOutputSelected = false
                                    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                        Task {
                                            hasDirectoryPermission = await requestDirectoryAccess(at: documentsURL.path)
                                            if !hasDirectoryPermission {
                                                DispatchQueue.main.async {
                                                    conversionResult = "❌ 未获得目录访问权限，无法创建语言子目录"
                                                    showResult = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // 使内容靠左对齐
                    
                    // 按钮部分保持原样（居中）
                    HStack(spacing: 12) {
                        Button("开始转换") {
                            convertToLocalization()
                        }
                        .disabled(!isInputSelected || !isOutputSelected || selectedLanguages.isEmpty || isLoading)
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: resetAll) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("重置")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                    
                    // 结果显示区域
                    if showResult {
                        VStack(spacing: 12) {
                            Text(conversionResult)
                                .foregroundColor(conversionResult.hasPrefix("✅") ? .green : .red)
                                .font(.system(.body, design: .rounded))
                            
                            if showSuccessActions {
                                VStack(spacing: 8) {
                                    Text("文件保存路径：")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(outputPath)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                    
                                    Button(action: openInFinder) {
                                        HStack {
                                            Image(systemName: "folder")
                                            Text("在 Finder 中显示")
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .padding(.top, 4)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .padding()
                .frame(maxWidth: 600)
            }
            .frame(minHeight: 500)
            .blur(radius: isLoading ? 3 : 0)
            
            // 加载指示器
            if isLoading {
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
