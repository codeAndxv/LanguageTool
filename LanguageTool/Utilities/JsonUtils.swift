import Foundation

class JsonUtils {
    /// 从 JSON 文件中提取键为中文字符串的键，删除重复项并写入 TXT 文件。
    ///
    /// - Parameters:
    ///   - jsonFilePath: JSON 文件路径。
    ///   - outputFilePath: 输出 TXT 文件路径。
    static func extractChineseKeys(from jsonFilePath: String, to outputFilePath: String) {
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonFilePath)) else {
            print("错误：文件 \(jsonFilePath) 未找到。")
            return
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            print("错误：文件 \(jsonFilePath) 不是有效的 JSON 格式。")
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

        do {
            try keysArray.joined(separator: "\n").write(toFile: outputFilePath, atomically: true, encoding: .utf8)
            print("成功提取 \(chineseKeys.count) 个中文键并写入 \(outputFilePath)。")
        } catch {
            print("写入文件 \(outputFilePath) 出错: \(error)")
        }
    }

    /// 新增方法：提取中文并返回字符串数组
    static func extractChineseKeysAsArray(from inputFilePath: String) -> [String]? {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputFilePath)),
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                print("❌ JSON 文件读取或解析失败")
                return nil
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
            print("✅ 成功提取 \(chineseKeys.count) 个中文键")
            return Array(chineseKeys)
            
        } catch {
            print("❌ 处理失败: \(error)")
            return nil
        }
    }

    /// 从JSON文件中提取中文键并生成本地化文件
    static func convertToLocalizationFile(from inputPath: String, to outputPath: String) -> (success: Bool, message: String) {
        guard let chineseKeys = extractChineseKeysAsArray(from: inputPath) else {
            return (false, "❌ 提取中文键失败")
        }
        
        guard let jsonData = LocalizationJSONGenerator.generateJSON(for: chineseKeys) else {
            return (false, "❌ 生成 JSON 失败")
        }
        
        do {
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            return (true, "✅ 成功生成本地化 JSON 文件，包含 \(chineseKeys.count) 个键")
        } catch {
            return (false, "❌ 写入文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 从JSON文件中提取中文键并生成文本文件
    static func extractChineseKeysToFile(from inputPath: String, to outputPath: String) -> (success: Bool, message: String) {
        do {
            guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)) else {
                return (false, "错误：文件未找到")
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
                return (false, "错误：不是有效的 JSON 格式")
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
            return (true, "✅ 成功提取 \(chineseKeys.count) 个中文键并写入文件")
        } catch {
            return (false, "❌ 转换失败：\(error.localizedDescription)")
        }
    }
}
