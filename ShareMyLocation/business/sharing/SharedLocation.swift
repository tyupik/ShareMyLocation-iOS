/**
 Бизнес-модель точки геолокации владельца: документ locations/{uid} в Firestore.
 Порт 1:1 из Android SharedLocation.kt. Записывается фоновым движком (этап 8) каждые ~5 секунд
 merge-set'ом {geo, accuracy, updatedAt}; получателей движок не вычисляет — свежесть (updatedAt)
 и адресатов определяет читатель (этап 7).
 */
struct SharedLocation {
    var latitude: Double
    var longitude: Double

    /// Радиус точности в метрах по данным провайдера; в правилах не валидируется.
    var accuracyMeters: Double
}
