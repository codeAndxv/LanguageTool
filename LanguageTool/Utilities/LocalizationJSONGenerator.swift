import Foundation
import AppKit

class LocalizationJSONGenerator {
    static func generateJSON(for keys: [String], languages: [String], sourceLanguage: String) async -> Data? {
        var localizationData: [String: Any] = [
            "version": "1.0",
            "sourceLanguage": sourceLanguage,
            "strings": [:]
        ]
        
        var stringsDict: [String: Any] = [:]
        
        // 语言名称映射
        let languageNames = [
            "en": "英语",
            "zh-Hans": "简体中文",
            "zh-Hant": "繁体中文",
            "ja": "日语",
            "ko": "韩语",
            "es": "西班牙语",
            "fr": "法语",
            "de": "德语"
        ]
        
        // 为每种语言批量翻译所有键
        for language in languages {
            if language == sourceLanguage {
                // 源语言不需要翻译
                for key in keys {
                    if stringsDict[key] == nil {
                        stringsDict[key] = ["localizations": [:]]
                    }
                    if var localizations = stringsDict[key] as? [String: Any],
                       var localizationsDict = localizations["localizations"] as? [String: Any] {
                        localizationsDict[language] = [
                            "stringUnit": [
                                "state": "translated",
                                "value": key
                            ]
                        ]
                        localizations["localizations"] = localizationsDict
                        stringsDict[key] = localizations
                    }
                }
            } else {
                do {
                    // 使用优化后的批量翻译方法
                    print("开始批量翻译 [\(language)]...")
                    let translations = try await AIService.shared.batchTranslate(
                        texts: keys,
                        to: languageNames[language] ?? language
                    )
                    
                    // 将翻译结果添加到字典中
                    for (index, key) in keys.enumerated() {
                        if stringsDict[key] == nil {
                            stringsDict[key] = ["localizations": [:]]
                        }
                        if var localizations = stringsDict[key] as? [String: Any],
                           var localizationsDict = localizations["localizations"] as? [String: Any],
                           index < translations.count {
                            localizationsDict[language] = [
                                "stringUnit": [
                                    "state": "translated",
                                    "value": translations[index]
                                ]
                            ]
                            localizations["localizations"] = localizationsDict
                            stringsDict[key] = localizations
                        }
                    }
                    
                    print("✅ 批量翻译成功 [\(language)]: \(keys.count) 个词条")
                } catch {
                    print("❌ 批量翻译失败 [\(language)]: \(error.localizedDescription)")
                    // 翻译失败时为所有键设置空值
                    for key in keys {
                        if stringsDict[key] == nil {
                            stringsDict[key] = ["localizations": [:]]
                        }
                        if var localizations = stringsDict[key] as? [String: Any],
                           var localizationsDict = localizations["localizations"] as? [String: Any] {
                            localizationsDict[language] = [
                                "stringUnit": [
                                    "state": "needs_review",
                                    "value": ""
                                ]
                            ]
                            localizations["localizations"] = localizationsDict
                            stringsDict[key] = localizations
                        }
                    }
                }
            }
        }
        
        localizationData["strings"] = stringsDict
        
        do {
            return try JSONSerialization.data(withJSONObject: localizationData, options: [.prettyPrinted, .sortedKeys])
        } catch {
            print("❌ 生成 JSON 失败: \(error)")
            return nil
        }
    }

    static func saveJSONToFile(data: Data?, fileName: String) { // 修改参数为文件名
        guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
            print("Invalid JSON data")
            return
        }

        // 获取 Documents 目录的路径
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents directory")
            return
        }

        // 创建文件路径
        let filePath = documentsDirectory.appendingPathComponent(fileName).path

        do {
            try jsonString.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("JSON file saved to \(filePath)")
        } catch {
            print("Error writing JSON to file: \(error)")
        }
    }
    
    /// 选择保存路径保存 json 文件
    /// - Parameter data: 待保存的数据
    static func saveJSONToFile(data: Data?) {
        guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
            print("Invalid JSON data")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true // 允许用户创建文件夹
        savePanel.title = "Save JSON File" // 设置窗口标题
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "\(dateFormatter.string(from: Date())).json"
        
        savePanel.nameFieldStringValue = fileName // 设置默认文件名

        // 显示保存面板
        savePanel.begin { (result) in
            if result == .OK {
                guard let url = savePanel.url else {
                    print("No URL selected")
                    return
                }

                do {
                    try jsonString.write(to: url, atomically: true, encoding: .utf8)
                    print("JSON file saved to \(url)")
                } catch {
                    print("Error writing JSON to file: \(error)")
                }
            }
        }
    }
}
