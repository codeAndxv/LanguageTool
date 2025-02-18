import Foundation

class StringsFileHandler {
    /// 从 .strings 文件中读取键值对
    static func readStringsFile(at path: String) -> [String: String]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过注释和空行
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                continue
            }
            
            // 解析键值对
            if let range = trimmed.range(of: "\" = \"") {
                let key = String(trimmed[..<range.lowerBound])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let value = String(trimmed[range.upperBound...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
                
                result[key] = value
            }
        }
        
        return result
    }
    
    /// 生成 .strings 文件
    static func generateStringsFile(translations: [String: String], to path: String) -> Bool {
        var content = "/* Localized by Language Tool */\n\n"
        
        for (key, value) in translations.sorted(by: { $0.key < $1.key }) {
            content += "\"\(key)\" = \"\(value)\";\n"
        }
        
        do {
            try content.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error writing .strings file: \(error)")
            return false
        }
    }
    
    /// 批量生成多语言 .strings 文件
    static func generateMultiLanguageStringsFiles(
        sourceKeys: [String],
        translations: [String: [String: String]], // [languageCode: [key: translation]]
        baseDirectory: String
    ) -> Bool {
        for (languageCode, translationDict) in translations {
            let languagePath = (baseDirectory as NSString)
                .appendingPathComponent("\(languageCode).lproj")
            let stringsPath = (languagePath as NSString)
                .appendingPathComponent("Localizable.strings")
            
            // 创建语言目录
            try? FileManager.default.createDirectory(
                atPath: languagePath,
                withIntermediateDirectories: true
            )
            
            // 生成 .strings 文件
            if !generateStringsFile(translations: translationDict, to: stringsPath) {
                return false
            }
        }
        
        return true
    }
} 