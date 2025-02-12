import Foundation
import AppKit

class LocalizationJSONGenerator {
    static func generateJSON(for keys: [String], languages: [String] = ["zh-Hans", "en", "zh-Hant", "ja", "ko", "es", "fr", "de"]) -> Data? {
        var localizationData: [String: Any] = [
            "version": "1.0",
            "sourceLanguage": "zh-Hans",
            "strings": [:]
        ]
        
        var stringsDict: [String: Any] = [:]
        
        for key in keys {
            var localizations: [String: Any] = [:]
            
            // 为每种语言创建本地化结构
            for language in languages {
                let value = language == "zh-Hans" ? key : ""
                localizations[language] = [
                    "stringUnit": [
                        "state": "translated",
                        "value": value
                    ]
                ]
            }
            
            stringsDict[key] = [
                "localizations": localizations
            ]
        }
        
        localizationData["strings"] = stringsDict
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: localizationData, options: [.prettyPrinted, .sortedKeys])
            return jsonData
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
