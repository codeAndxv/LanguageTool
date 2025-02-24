import Foundation

class StringsFileHandler {
    /// 从 .strings 文件中读取键值对
    static func readStringsFile(at path: String) -> Result<[String: String], Error> {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var result: [String: String] = [:]
            
            // 按行分割
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // 跳过注释和空行
                if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                
                // 匹配 "key" = "value"; 格式
                if let regex = try? NSRegularExpression(pattern: "\"(.+?)\"\\s*=\\s*\"(.+?)\";") {
                    let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                    if let match = regex.firstMatch(in: trimmed, options: [], range: nsRange) {
                        if let keyRange = Range(match.range(at: 1), in: trimmed),
                           let valueRange = Range(match.range(at: 2), in: trimmed) {
                            let key = String(trimmed[keyRange])
                            let value = String(trimmed[valueRange])
                            result[key] = value
                        }
                    }
                }
            }
            
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    /// 生成 .strings 文件
    static func generateStringsFile(translations: [String: String], to path: String) -> Result<Void, Error> {
        do {
            var content = "/* Generated by Language Tool */\n\n"
            
            // 对键进行排序，保证输出顺序一致
            let sortedKeys = translations.keys.sorted()
            
            // 生成所有翻译行
            let translationLines = sortedKeys.compactMap { key -> String? in
                guard let value = translations[key] else { return nil }
                
                // 更严格的文本清理
                let cleanedValue = value
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .joined(separator: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                
                // 确保值不为空
                guard !cleanedValue.isEmpty else { return nil }
                
                return "\"\(key)\" = \"\(cleanedValue)\";"
            }
            
            // 将所有行组合并确保最后没有多余的换行符
            content += translationLines.joined(separator: "\n")
            
            // 确保文件以单个换行符结束
            if !content.hasSuffix("\n") {
                content += "\n"
            }
            
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// 将 .strings 格式转换为 .xcstrings 格式
    static func convertToXCStrings(translations: [String: String], languages: [String]) async -> Result<Data, Error> {
        var xcstringsDict: [String: Any] = [
            "version": "1.0",
            "sourceLanguage": "zh-Hans",
            "strings": [:] as [String: Any]
        ]
        
        var stringsDict: [String: Any] = [:]
        
        for (key, sourceValue) in translations {
            var localizationsDict: [String: Any] = [:]
            
            // 为每种语言创建翻译
            for language in languages {
                if language == "zh-Hans" {
                    // 源语言使用原始值
                    localizationsDict[language] = [
                        "stringUnit": [
                            "state": "translated",
                            "value": sourceValue
                        ]
                    ]
                } else {
                    do {
                        // 使用 AI 服务翻译
                        let translation = try await AIService.shared.translate(
                            text: sourceValue,
                            to: language
                        )
                        localizationsDict[language] = [
                            "stringUnit": [
                                "state": "translated",
                                "value": translation
                            ]
                        ]
                    } catch {
                        print("翻译失败 [\(language)]: \(error.localizedDescription)")
                        localizationsDict[language] = [
                            "stringUnit": [
                                "state": "needs_review",
                                "value": ""
                            ]
                        ]
                    }
                }
            }
            
            stringsDict[key] = ["localizations": localizationsDict]
        }
        
        xcstringsDict["strings"] = stringsDict
        
        do {
            return .success(try JSONSerialization.data(withJSONObject: xcstringsDict, options: [.prettyPrinted, .sortedKeys]))
        } catch {
            return .failure(error)
        }
    }
} 
