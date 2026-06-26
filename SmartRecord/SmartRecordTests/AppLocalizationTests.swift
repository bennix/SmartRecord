import Testing
@testable import SmartRecord

struct AppLocalizationTests {
    @Test func everyTextKeyHasEverySupportedLanguage() {
        for language in AppLanguage.allCases {
            let strings = AppStrings(language)
            for key in AppText.allCases {
                let value = strings(key)
                #expect(!value.isEmpty, "\(key.rawValue) is empty for \(language.rawValue)")
                #expect(value != key.rawValue, "\(key.rawValue) is missing for \(language.rawValue)")
            }
        }
    }
}
