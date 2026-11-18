import Factory

/// Binding интерактора шаринга (аналог Android SharingInteractorModule.kt).
/// Синглтон: realtime-состояние isEnabled переживает экраны (нужно движку, этап 8).
extension Container {
    var sharingInteractor: Factory<SharingInteractor> {
        self {
            SharingInteractorImpl(sharingRepository: self.sharingRepository())
        }.singleton
    }
}
