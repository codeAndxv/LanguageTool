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
        
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                self.inputPath = fileURL.path
                self.isInputSelected = true
                
                // 根据输入文件类型自动设置输出格式
                let fileExtension = fileURL.pathExtension.lowercased()
                if fileExtension == "strings" {
                    self.outputFormat = .strings
                    // 重置输出路径，因为格式改变了
                    self.outputPath = "未选择保存位置"
                    self.isOutputSelected = false
                } else {
                    self.outputFormat = .xcstrings
                }
            }
        }
    }
    
    private func selectOutputPath() {
        // 对于 .strings 格式，使用目录选择面板
        if outputFormat == .strings {
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
                    // 测试目录写入权限
                    let testPath = directoryURL.appendingPathComponent(".test_write_permission")
                    do {
                        try "test".write(to: testPath, atomically: true, encoding: .utf8)
                        try FileManager.default.removeItem(at: testPath)
                        
                        // 如果测试成功，设置输出路径
                        self.outputPath = directoryURL.path
                        self.isOutputSelected = true
                    } catch {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "权限错误"
                            alert.informativeText = "无法获得目录的写入权限，请选择其他位置或检查系统权限设置。"
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                        }
                    }
                }
            }
        } else {
            // .xcstrings 文件的保存逻辑保持不变
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
                let fileExtension = (inputPath as NSString).pathExtension.lowercased()
                
                switch fileExtension {
                case "strings":
                    let parseResult = StringsFileParser.parseStringsFile(at: inputPath)
                    switch parseResult {
                    case .success(let translations):
                        if outputFormat == .xcstrings {
                            // xcstrings 处理逻辑保持不变...
                        } else {
                            print("开始生成 .strings 文件...")
                            
                            // 使用 URL 处理路径
                            let baseURL = URL(fileURLWithPath: outputPath)
                            print("基础目录: \(baseURL.path)")
                            
                            for language in selectedLanguages {
                                print("处理语言: \(language.code)")
                                // 使用 URL 创建语言目录路径
                                let langURL = baseURL.appendingPathComponent("\(language.code).lproj")
                                let stringsURL = langURL.appendingPathComponent("Localizable.strings")
                                
                                print("创建目录: \(langURL.path)")
                                do {
                                    // 使用 URL 创建目录
                                    try FileManager.default.createDirectory(
                                        at: langURL,
                                        withIntermediateDirectories: true,
                                        attributes: nil
                                    )
                                    
                                    if language.code == "zh-Hans" {
                                        print("处理源语言文件...")
                                        // 源语言直接使用原始值
                                        let result = StringsFileParser.generateStringsFile(
                                            translations: translations,
                                            to: stringsURL.path
                                        )
                                        if case .failure(let error) = result {
                                            throw error
                                        }
                                    } else {
                                        print("开始翻译: \(language.code)")
                                        // 其他语言需要翻译
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
                                        let result = StringsFileParser.generateStringsFile(
                                            translations: translatedDict,
                                            to: stringsURL.path
                                        )
                                        if case .failure(let error) = result {
                                            throw error
                                        }
                                    }
                                } catch {
                                    print("处理语言 \(language.code) 时出错: \(error.localizedDescription)")
                                    throw error
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
                    // 其他格式处理逻辑保持不变...
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
    
    // 添加一个辅助方法来更新文件扩展名
    private func updateOutputPathExtension(to format: LocalizationFormat) {
        // 如果还没有选择保存路径，不需要更新
        if outputPath == "未选择保存位置" {
            return
        }
        
        // 获取当前路径的组件
        let url = URL(fileURLWithPath: outputPath)
        let directory = url.deletingLastPathComponent().path
        let fileName = url.deletingPathExtension().lastPathComponent
        
        // 根据新格式设置扩展名
        let newExtension = format == .xcstrings ? "xcstrings" : "strings"
        
        // 构建新路径
        outputPath = (directory as NSString).appendingPathComponent("\(fileName).\(newExtension)")
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
                                .padding(.horizontal)
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
                            .onChange(of: outputFormat) { oldValue, newValue in
                                // 只有在已经选择了保存路径的情况下才更新扩展名
                                if outputPath != "未选择保存位置" {
                                    updateOutputPathExtension(to: newValue)
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

//
//import SwiftUI
//
//struct ContentView: View {
//    @State private var showAlert = false
//    @State private var showPermissionDeniedAlert = false
//    @State private var errorMessage = ""
//    @State private var selectedDirectory: URL? = nil
//
//    var body: some View {
//        Button("选择目录并创建文件夹") {
//            selectDirectoryAndCreateFolder()
//        }
//        .alert(isPresented: $showAlert) {
//            Alert(title: Text("错误"), message: Text(errorMessage), dismissButton: .default(Text("确定")))
//        }
//        .alert(isPresented: $showPermissionDeniedAlert) {
//            Alert(
//                title: Text("权限被拒绝"),
//                message: Text("您拒绝了访问所选目录的权限，应用将无法正常工作。"),
//                dismissButton: .default(Text("确定"))
//            )
//        }
//    }
//
//    func selectDirectoryAndCreateFolder() {
//        let openPanel = NSOpenPanel()
//        openPanel.canChooseFiles = false
//        openPanel.canChooseDirectories = true
//        openPanel.allowsMultipleSelection = false
//        openPanel.prompt = "选择要保存文件夹的目录"
//
//        let result = openPanel.runModal()
//
//        if result == .OK {
//            guard let url = openPanel.urls.first else { return }
//            selectedDirectory = url
//
//            createFolder(at: url)
//        }
//    }
//
//    func createFolder(at directory: URL) {
//        let fileManager = FileManager.default
//        let folderName = "NewFolder"
//        let folderURL = directory.appendingPathComponent(folderName)
//
//        do {
//            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
//            print("文件夹创建成功")
//        } catch {
//            errorMessage = error.localizedDescription
//            showAlert = true
//            print("创建文件夹失败：\(error)")
//
//            // 检查是否是权限错误
////            if let nsError = error as NSError {
////                if nsError.code == NSFileReadUnknownError {
////                    // 用户拒绝了访问权限
////                    showPermissionDeniedAlert = true
////                }
////            }
//        }
//    }
//}
