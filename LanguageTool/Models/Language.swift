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
        Language(code: "zh-Hant", name: "Chinese, Traditional", localizedName: "繁體中文"),
        Language(code: "zh-HK", name: "Chinese, Hong Kong", localizedName: "繁體中文（香港）"),
        
        // 英语变体
        Language(code: "en", name: "English", localizedName: "English"),
        Language(code: "en-AU", name: "English, Australia", localizedName: "English (Australia)"),
        Language(code: "en-GB", name: "English, UK", localizedName: "English (UK)"),
        Language(code: "en-IN", name: "English, India", localizedName: "English (India)"),
        Language(code: "en-CA", name: "English, Canada", localizedName: "English (Canada)"),
        
        // 欧洲语言
        Language(code: "fr", name: "French", localizedName: "Français"),
        Language(code: "fr-CA", name: "French, Canada", localizedName: "Français (Canada)"),
        Language(code: "es", name: "Spanish", localizedName: "Español"),
        Language(code: "es-419", name: "Spanish, Latin America", localizedName: "Español (Latinoamérica)"),
        Language(code: "de", name: "German", localizedName: "Deutsch"),
        Language(code: "it", name: "Italian", localizedName: "Italiano"),
        Language(code: "pt", name: "Portuguese", localizedName: "Português"),
        Language(code: "pt-BR", name: "Portuguese, Brazil", localizedName: "Português (Brasil)"),
        Language(code: "pt-PT", name: "Portuguese, Portugal", localizedName: "Português (Portugal)"),
        Language(code: "ru", name: "Russian", localizedName: "Русский"),
        Language(code: "pl", name: "Polish", localizedName: "Polski"),
        Language(code: "tr", name: "Turkish", localizedName: "Türkçe"),
        Language(code: "nl", name: "Dutch", localizedName: "Nederlands"),
        Language(code: "sv", name: "Swedish", localizedName: "Svenska"),
        Language(code: "da", name: "Danish", localizedName: "Dansk"),
        Language(code: "fi", name: "Finnish", localizedName: "Suomi"),
        Language(code: "nb", name: "Norwegian Bokmål", localizedName: "Norsk bokmål"),
        Language(code: "el", name: "Greek", localizedName: "Ελληνικά"),
        Language(code: "cs", name: "Czech", localizedName: "Čeština"),
        Language(code: "hu", name: "Hungarian", localizedName: "Magyar"),
        Language(code: "sk", name: "Slovak", localizedName: "Slovenčina"),
        Language(code: "uk", name: "Ukrainian", localizedName: "Українська"),
        Language(code: "hr", name: "Croatian", localizedName: "Hrvatski"),
        Language(code: "ca", name: "Catalan", localizedName: "Català"),
        Language(code: "ro", name: "Romanian", localizedName: "Română"),
        Language(code: "he", name: "Hebrew", localizedName: "עברית"),
        
        // 亚洲语言
        Language(code: "ja", name: "Japanese", localizedName: "日本語"),
        Language(code: "ko", name: "Korean", localizedName: "한국어"),
        Language(code: "th", name: "Thai", localizedName: "ไทย"),
        Language(code: "vi", name: "Vietnamese", localizedName: "Tiếng Việt"),
        Language(code: "hi", name: "Hindi", localizedName: "हिन्दी"),
        Language(code: "bn", name: "Bengali", localizedName: "বাংলা"),
        Language(code: "id", name: "Indonesian", localizedName: "Bahasa Indonesia"),
        Language(code: "ms", name: "Malay", localizedName: "Bahasa Melayu"),
        
        // 中东语言
        Language(code: "ar", name: "Arabic", localizedName: "العربية"),
        Language(code: "ar-SA", name: "Arabic, Saudi Arabia", localizedName: "العربية (السعودية)"),
        Language(code: "fa", name: "Persian", localizedName: "فارسی"),
        Language(code: "ur", name: "Urdu", localizedName: "اردو"),
        
        // 其他语言
        Language(code: "fil", name: "Filipino", localizedName: "Filipino"),
        Language(code: "km", name: "Khmer", localizedName: "ខ្មែរ"),
        Language(code: "mn", name: "Mongolian", localizedName: "Монгол"),
        Language(code: "my", name: "Burmese", localizedName: "မြန်မာ"),
        Language(code: "ne", name: "Nepali", localizedName: "नेपाली"),
        Language(code: "si", name: "Sinhala", localizedName: "සිංහල"),
        Language(code: "az", name: "Azerbaijani", localizedName: "Azərbaycan"),
        Language(code: "kk", name: "Kazakh", localizedName: "Қазақ"),
        Language(code: "hy", name: "Armenian", localizedName: "Հայերեն"),
        Language(code: "ka", name: "Georgian", localizedName: "ქართული")
    ]
} 
