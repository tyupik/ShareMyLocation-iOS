/// Нормализация и валидация телефона профиля.
/// Российские номера канонизируются к виду 8XXXXXXXXXX независимо от формата ввода:
/// «+79999999999», «+7 999 999-99-99», «89999999999», «+7 (999) 999-99-99», «8 (999) 999-99-99»
/// и т.д. — все дают «89999999999». Номер без кода страны (10 цифр) дополняется восьмёркой.
/// Иностранные номера (11–15 цифр, не RU-шаблон) сохраняют ведущий «+», если он был в вводе.
/// Порт 1:1 из Android PhoneNormalizer.kt.
enum PhoneNormalizer {

    /// Минимальное и максимальное число цифр в валидном телефоне (с кодом страны).
    static let MIN_DIGITS = 10
    static let MAX_DIGITS = 15

    /// Число цифр российского номера с кодом страны.
    private static let RU_PHONE_DIGITS = 11

    /// Число цифр российского номера без кода страны.
    private static let RU_PHONE_NO_CODE_DIGITS = 10

    /// Восьмёрка — канонический префикс российских номеров на бэкенде.
    private static let RU_TRUNK_PREFIX = "8"

    /// Канонизирует `raw` для отправки на бэкенд: российский номер — строго 8XXXXXXXXXX,
    /// иначе только цифры с сохранением ведущего «+» исходной строки.
    static func normalize(_ raw: String) -> String {
        let digits = String(raw.filter(Self.isAsciiDigit))
        if digits.count == RU_PHONE_DIGITS, let first = digits.first, first == "7" || first == "8" {
            return RU_TRUNK_PREFIX + String(digits.dropFirst())
        }
        if digits.count == RU_PHONE_NO_CODE_DIGITS {
            return RU_TRUNK_PREFIX + digits
        }
        // Ведущий «+» ищется в строке без стартовых пробелов (порт Android trimStart()).
        return raw.drop(while: \.isWhitespace).hasPrefix("+") ? "+\(digits)" : digits
    }

    /// Количество цифр в строке (ведущий «+» не учитывается).
    static func digitCount(_ phone: String) -> Int {
        phone.filter(Self.isAsciiDigit).count
    }

    /// Строго ASCII-цифры: Kotlin Char::isDigit — категория Nd, а Swift isNumber шире
    /// (включает Nl/No: «Ⅷ», «²»); для совпадения цифрового счёта с Android фильтруем
    /// только "0"..."9" (телефонный ввод других цифр не содержит).
    private static func isAsciiDigit(_ character: Character) -> Bool {
        "0" <= character && character <= "9"
    }

    /// Валидный телефон — 10–15 цифр после нормализации.
    static func isValid(_ phone: String) -> Bool {
        (MIN_DIGITS...MAX_DIGITS).contains(digitCount(phone))
    }
}
