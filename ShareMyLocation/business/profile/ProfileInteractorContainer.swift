import Factory

/// Binding интерактора профиля (аналог Android ProfileInteractorModule.kt).
extension Container {
    var profileInteractor: Factory<ProfileInteractor> {
        self {
            ProfileInteractorImpl(profileRepository: self.profileRepository())
        }
    }
}
