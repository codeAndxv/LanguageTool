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
    @State private var selectedPlatform: PlatformType = .iOS
    
    private let columns = [
        GridItem(.adaptive(minimum: 160))
    ]
    
    private func selectInputFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        // 根据选择的平台设置允许的文件类型
        var allowedTypes: [UTType] = []
        
        switch selectedPlatform {
        case .iOS:
            // 使用文件扩展名来识别文件类型
            if let xcstringsType = UTType(filenameExtension: "xcstrings") {
                allowedTypes.append(xcstringsType)
            }
            if let stringsType = UTType(filenameExtension: "strings") {
                allowedTypes.append(stringsType)
            }
            
//            // 支持 .json、.xcstrings 和 .strings 文件
//            let xcstringsType = UTType("com.apple.xcode.strings-text")! // Xcode 的 .xcstrings 类型
//            let stringsType = UTType.propertyList // .strings 文件实际上是属性列表类型
//            panel.allowedContentTypes = [.json, xcstringsType, stringsType]
            
        case .flutter:
            if let arbType = UTType(filenameExtension: "arb") {
                allowedTypes.append(arbType)
            }
            
        case .electron:
            // 只允许纯 JSON 文件
            allowedTypes = [UTType.json]  // 使用系统预定义的 JSON 类型
        }
        
        // 确保至少有一个文件类型被设置
        if allowedTypes.isEmpty {
            print("警告：没有设置任何文件类型")
            allowedTypes = [.json]  // 默认使用 JSON 类型
        }
        
        panel.allowedContentTypes = allowedTypes
        
        // 根据平台设置提示信息
        panel.title = "选择本地化文件"
        switch selectedPlatform {
        case .iOS:
            panel.message = "请选择 .strings 或 .xcstrings 文件"
        case .flutter:
            panel.message = "请选择 .arb 文件"
        case .electron:
            panel.message = "请选择 .json 文件"
        }
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                // 关键修改 2: 校验文件扩展名
                switch selectedPlatform {
                case .electron:
                    let fileExtension = fileURL.pathExtension.lowercased()
                    guard fileExtension == "json" else {
                        // 显示错误提示
                        self.showErrorAlert(message: "Electron 平台仅支持 .json 文件")
                        return
                    }
                default: break
                }
                
                self.inputPath = fileURL.path
                self.isInputSelected = true
                
                // 根据选择的平台设置输出格式
                switch selectedPlatform {
                case .iOS:
                    let fileExtension = fileURL.pathExtension.lowercased()
                    self.outputFormat = fileExtension == "strings" ? .strings : .xcstrings
                case .flutter:
                    self.outputFormat = .arb
                case .electron:
                    self.outputFormat = .electron  // 新增 .electron 格式
                }
                
                // 重置输出路径
                self.outputPath = "未选择保存位置"
                self.isOutputSelected = false
            }
        }
    }
    
    private func selectOutputPath() {
        switch outputFormat {
        case .electron:
            // 对于 Electron 格式，使用目录选择面板
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "请选择保存 JSON 文件的目录"
            openPanel.prompt = "选择"
            openPanel.title = "选择保存目录"
            
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .arb:
            // 对于 ARB 格式，使用目录选择面板
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "请选择保存 ARB 文件的目录"
            openPanel.prompt = "选择"
            openPanel.title = "选择保存目录"
            
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .strings:
            // 现有的 .strings 格式处理逻辑
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "请选择保存语言文件的目录"
            openPanel.prompt = "选择"
            openPanel.title = "选择保存目录"
            
            // 设置可以访问的目录类型
            openPanel.treatsFilePackagesAsDirectories = true
            
            openPanel.begin { [self] response in
                if response == .OK, let directoryURL = openPanel.url {
                    self.outputPath = directoryURL.path
                    self.isOutputSelected = true
                }
            }
            
        case .xcstrings:
            // 现有的 .xcstrings 格式处理逻辑
            let panel = NSSavePanel()
            if let xcstringsType = UTType(filenameExtension: "xcstrings") {
                panel.allowedContentTypes = [xcstringsType]
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            let defaultFileName = "Localizable_\(timestamp)"
            panel.nameFieldStringValue = defaultFileName
            
            panel.canCreateDirectories = true
            panel.title = "保存本地化文件"
            panel.message = "选择保存 .xcstrings 文件的位置"
            
            panel.begin { [self] response in
                if response == .OK, let fileURL = panel.url {
                    self.outputPath = fileURL.path
                    self.isOutputSelected = true
                }
            }
        }
    }
    
//    private func performConversion() {
//        let result = JsonUtils.extractChineseKeysToFile(from: inputPath, to: outputPath)
//        conversionResult = result.message
//        showResult = true
//    }
    
    private func convertToLocalization() {
        Task {
            isLoading = true
            showResult = false
            showSuccessActions = false
            
            let fileExtension = (inputPath as NSString).pathExtension.lowercased()
            let result: (message: String, success: Bool)
            
            switch selectedPlatform {
            case .iOS:
                switch fileExtension {
                case "strings":
                    let processResult = await StringsFileParser.processStringsFile(
                        from: inputPath,
                        to: outputPath,
                        format: outputFormat,
                        languages: selectedLanguages
                    )
                    switch processResult {
                    case .success(let message):
                        result = (message: message, success: true)
                    case .failure(let error):
                        result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                    }
                case "xcstrings":
                    let conversionResult = await JsonUtils.convertToLocalizationFile(
                        from: inputPath,
                        to: outputPath,
                        languages: Array(selectedLanguages).map { $0.code }
                    )
                    result = (message: conversionResult.message, success: conversionResult.success)
                default:
                    result = (message: "❌ 不支持的文件格式", success: false)
                }
                
            case .flutter:
                let processResult = await ARBFileHandler.processARBFile(
                    from: inputPath,
                    to: outputPath,
                    languages: Array(selectedLanguages).map { $0.code }
                )
                switch processResult {
                case .success(let message):
                    result = (message: message, success: true)
                case .failure(let error):
                    result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                }
                
            case .electron:
                // 严格校验输入文件类型
                guard fileExtension == "json" else {
                    result = (message: "❌ Electron 平台仅支持 .json 文件", success: false)
                    break
                }
                let processResult = await ElectronLocalizationHandler.processLocalizationFile(
                    from: inputPath,
                    to: outputPath,
                    languages: Array(selectedLanguages).map { $0.code }
                )
                switch processResult {
                case .success(let message):
                    result = (message: message, success: true)
                case .failure(let error):
                    result = (message: "❌ 转换失败：\(error.localizedDescription)", success: false)
                }
            }
            
            DispatchQueue.main.async {
                self.conversionResult = result.message
                self.showSuccessActions = result.success
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
    
    // MARK: - 新增错误提示方法
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "文件类型错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 添加平台选择部分
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择平台")
                            .font(.headline)
                        
                        Picker("平台", selection: $selectedPlatform) {
                            ForEach(PlatformType.allCases, id: \.self) { platform in
                                Text(platform.description)
                                    .tag(platform)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedPlatform) { oldValue, newValue in
                            // 切换平台时重置状态
                            resetAll()
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // 文件选择部分
                    VStack(alignment: .leading, spacing: 20) {
                        // 左对齐的内容容器
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
                                .padding(.horizontal)
                            }
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // 输出格式选择部分
//                        VStack(alignment: .leading, spacing: 10) {
//                            Text("输出格式")
//                                .font(.headline)
//                            
//                            Picker("输出格式", selection: $outputFormat) {
//                                Text("Xcode Strings Catalog (.xcstrings)")
//                                    .tag(LocalizationFormat.xcstrings)
//                                Text("Strings File (.strings)")
//                                    .tag(LocalizationFormat.strings)
//                            }
//                            .pickerStyle(.radioGroup)
//                            .onChange(of: outputFormat) { oldValue, newValue in
//                                // 每次切换格式时都重置输出路径
//                                outputPath = "未选择保存位置"
//                                isOutputSelected = false
//                            }
//                        }
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
