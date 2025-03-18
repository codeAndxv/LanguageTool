import Foundation

struct Language: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let localizedName: String
    
    // 支持 Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.code == rhs.code
    }
    
    // Xcode 支持的完整语言列表
    static let supportedLanguages: [Language] = [
        // 中文
        Language(code: "zh-Hans", name: "Chinese, Simplified", localizedName: "简体中文"),
        
        // 英语变体
        Language(code: "en", name: "English", localizedName: "English"),
        
        // 欧洲语言
        Language(code: "fr", name: "French", localizedName: "Français"),
        Language(code: "es", name: "Spanish", localizedName: "Español"),
        Language(code: "de", name: "German", localizedName: "Deutsch"),
        Language(code: "it", name: "Italian", localizedName: "Italiano"),
        Language(code: "pt-BR", name: "Portuguese, Brazil", localizedName: "Português (Brasil)"),
        Language(code: "ru", name: "Russian", localizedName: "Русский"),
        
        // 亚洲语言
        Language(code: "ja", name: "Japanese", localizedName: "日本語"),
        Language(code: "ko", name: "Korean", localizedName: "한국어"),
        
        // 中东语言
        Language(code: "ar", name: "Arabic", localizedName: "العربية")
    ]
} 
