import Foundation

/**
 Ui-модель видимого друга: точка карты + аватар (резолвится асинхронно) + «как давно».
 Порт 1:1 из Android VisibleFriendUiModel.
 */
struct VisibleFriendUiModel {
    let uid: String
    let displayName: String
    let avatarVersion: Int

    /// Путь к файлу аватара в кэше приложения; nil — плейсхолдер с инициалом.
    var avatarPath: String?

    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let updatedAtMillis: Int64

    /**
     «как давно»: «Только что» (≤ 30 с), «30 секунд назад» (30–60 с), минуты (≥ 60 с);
     обновляется тиками 5 с и ScreenShown.
     */
    let lastSeenLabel: String
}

/**
 Последняя известная точка текущего пользователя для центровки камеры (без maps-типов
 в контракте). updatedAtMillis — момент получения фикса, а не данных Firestore:
 повторный фикс по тем же координатам (неподвижный пользователь) перезапускает
 camera-эффект — срабатывают и кнопка «Показать меня», и автоцентровка при входе.
 Порт 1:1 из Android MyLocationUiModel.
 */
struct MyLocationUiModel {
    let latitude: Double
    let longitude: Double
    let updatedAtMillis: Int64
}

/**
 Конвертер бизнес-моделей карты в Ui-модели вкладки «Карта».
 Порт 1:1 из Android MapUiConverter (DateUtils → ручная плюрализация минут).
 */
struct MapUiConverter {
    /**
     avatarPath заполняется ViewModel после дозагрузки аватара; «как давно» считается
     lastSeenLabel: «Только что» (≤ 30 с), «30 секунд назад» (30–60 с), далее минуты
     с русской плюрализацией; для остановившейся точки метка «замораживается»
     до тика/ScreenShown.
     */
    func convertVisibleFriend(_ friend: VisibleFriend, nowMillis: Int64) -> VisibleFriendUiModel {
        VisibleFriendUiModel(
            uid: friend.uid,
            displayName: friend.displayName,
            avatarVersion: friend.avatarVersion,
            avatarPath: nil,
            latitude: friend.latitude,
            longitude: friend.longitude,
            accuracyMeters: friend.accuracyMeters,
            updatedAtMillis: friend.updatedAtMillis,
            lastSeenLabel: lastSeenLabel(friend.updatedAtMillis, nowMillis),
        )
    }

    /**
     Фикс собственной локации (SharedLocation из business.sharing переиспользуется
     провайдером) в Ui-модель центровки; точность карте для центровки не нужна.
     */
    func convertMyLocation(_ location: SharedLocation, nowMillis: Int64) -> MyLocationUiModel {
        MyLocationUiModel(
            latitude: location.latitude,
            longitude: location.longitude,
            updatedAtMillis: nowMillis,
        )
    }

    /**
     Метка «как давно» по updatedAtMillis относительно nowMillis, три ветки:
     - ≤ JUST_NOW_THRESHOLD_MS (включая точки из будущего, elapsed < 0) — «Только что»;
     - < MINUTE_IN_MILLIS — фиксированная «30 секунд назад» (без плюрализации);
     - иначе — минуты с русской плюрализацией («1 минуту назад» / «2 минуты назад» /
       «5 минут назад»).
     Границы: ровно 30 000 мс → «Только что», ровно 60 000 мс → минуты; из-за тикера 5 с
     пограничные состояния могут держаться до 5 с дольше — приемлемо.
     */
    private func lastSeenLabel(_ updatedAtMillis: Int64, _ nowMillis: Int64) -> String {
        let elapsedMillis = nowMillis - updatedAtMillis
        if elapsedMillis <= Self.JUST_NOW_THRESHOLD_MS {
            return "Только что"
        }
        if elapsedMillis < Self.MINUTE_IN_MILLIS {
            return "30 секунд назад"
        }
        let minutes = Int(elapsedMillis / Self.MINUTE_IN_MILLIS)
        return "\(minutes) \(pluralMinute(for: minutes)) назад"
    }

    /** Русская плюрализация «минут»: 1/21/31… — «минуту», 2–4/22–24… — «минуты», иначе — «минут». */
    private func pluralMinute(for minutes: Int) -> String {
        let mod100 = minutes % 100
        let mod10 = minutes % 10
        if mod100 >= 11 && mod100 <= 14 {
            return "минут"
        }
        switch mod10 {
        case 1:
            return "минуту"
        case 2, 3, 4:
            return "минуты"
        default:
            return "минут"
        }
    }

    /// Порог «Только что»: elapsed ≤ 30 с (верхняя граница минутной ветки — минута).
    private static let JUST_NOW_THRESHOLD_MS: Int64 = 30_000

    /// Длина минуты в millis (MINUTE_IN_MILLIS Android).
    private static let MINUTE_IN_MILLIS: Int64 = 60_000
}
