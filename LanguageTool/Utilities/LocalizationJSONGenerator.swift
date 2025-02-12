import Foundation
import AppKit

class LocalizationJSONGenerator {
    static func generateJSON(for keys: [String], sourceLanguage: String = "en") -> Data? {
        var localizationData: [String: Any] = [:]
        localizationData["sourceLanguage"] = sourceLanguage
        localizationData["strings"] = [:]

        for key in keys {
            // 将 localizationData["strings"] 转换为 [String: Any] 类型
            if var strings = localizationData["strings"] as? [String: Any] {
                strings[key] = [
                    "localizations": [
                        sourceLanguage: [
                            "stringUnit": [
                                "state": "translated",
                                "value": key
                            ]
                        ]
                    ]
                ]
                localizationData["strings"] = strings // 更新 localizationData["strings"]
            }
        }

        localizationData["version"] = "1.0"

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: localizationData, options: .prettyPrinted)
            return jsonData
        } catch {
            print("Error generating JSON: \(error)")
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
