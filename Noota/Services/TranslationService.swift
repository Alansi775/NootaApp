// Noota/Services/TranslationService.swift

import Foundation
import Combine

// يجب أن تكون هذه الخريطة مطابقة لـ supportedLanguages في ViewModel
// ولكن نستخدم الأسماء الكاملة لمساعدة نموذج LLM
struct LanguageMapper {
    static let languageMap: [String: String] = [
        "en-US": "English",
        "ar-SA": "Arabic", // أو "العربية" حسب تفضيلك لمدخلات LLM
        "tr-TR": "Turkish",
        "es-ES": "Spanish",
        "fr-FR": "French",
        "de-DE": "German",
        "it-IT": "Italian",
        "pt-BR": "Portuguese",
        "ru-RU": "Russian",
        "ja-JP": "Japanese",
        "zh-CN": "Simplified Chinese",
        "ko-KR": "Korean"
    ]
    
    static func codeToName(_ code: String) -> String {
        return languageMap[code] ?? code // إذا لم يعثر على اسم، يعيد الكود نفسه
    }
}

//  نموذج أخطاء للمساعدة في التتبع
enum TranslationError: Error, LocalizedError {
    case emptyResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Gemini returned an empty or invalid response."
        case .apiError(let message):
            return "Gemini API Error: \(message)"
        }
    }
}

class TranslationService: ObservableObject {
    
    //  1. إضافة خاصية GeminiService
    private let geminiService: GeminiService // 💡 يتطلب تمريره في init
    
    init(geminiService: GeminiService) {
        self.geminiService = geminiService
        Logger.log("TranslationService initialized with GeminiService.", level: .info)
    }

    func translate(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String {
        
        guard !text.isEmpty else { return "" }
        
        // 2. الحصول على أسماء اللغات لـ Gemini
        let sourceName = LanguageMapper.codeToName(sourceLanguage)
        let targetName = LanguageMapper.codeToName(targetLanguage)
        
        // 3. إعداد Prompt واضح ودقيق
        let prompt = """
        You are a real-time, professional, and precise translator. Your ONLY goal is to translate the user's text from \(sourceName) to \(targetName). 
        You MUST NOT include any conversational filler, explanations, introductory phrases, or extra dialogue like "The translation is:", "Hello,", or "I will translate this."
        Strictly return ONLY the translated sentence and nothing else.

        Text to translate: "\(text)"
        """
        
        Logger.log("Sending translation prompt to Gemini: from \(sourceName) to \(targetName)", level: .debug)

        do {
            // 4. استدعاء خدمة Gemini الفعلية
            let response = try await geminiService.generateContent(prompt: prompt)
            
            guard let translatedText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !translatedText.isEmpty else {
                throw TranslationError.emptyResponse
            }
            
            Logger.log(" Translation received: \(translatedText)", level: .info)
            return translatedText
            
        } catch let error as TranslationError {
            Logger.log("Translation failed with custom error: \(error.localizedDescription)", level: .error)
            throw error // إعادة إرسال أخطاء الترجمة المحددة
        } catch {
            Logger.log("Translation failed with generic error: \(error.localizedDescription)", level: .error)
            throw TranslationError.apiError(error.localizedDescription) // تغليف أي خطأ آخر
        }
    }
}
