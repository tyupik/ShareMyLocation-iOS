import Foundation
import Observation

/// ViewModel вкладки «Профиль»: перечитывает профиль при каждом показе вкладки.
/// Аватар резолвится асинхронно после основного контента: вкладка сразу показывает
/// плейсхолдер с инициалом, ошибка аватара не ломает вкладку.
/// Через ProfileUiConverter переводит бизнес-модель в Ui-модель. Порт 1:1
/// из Android ProfileViewModel.kt. Единственная публичная точка входа для UI — onIntent.
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: ProfileUiState = .initial

    /// One-off события экрана (порт Channel(BUFFERED) + receiveAsFlow).
    let effects: AsyncStream<ProfileEffect>
    private let effectsContinuation: AsyncStream<ProfileEffect>.Continuation

    private let profileInteractor: ProfileInteractor
    private let profileUiConverter: ProfileUiConverter

    init(profileInteractor: ProfileInteractor, profileUiConverter: ProfileUiConverter) {
        self.profileInteractor = profileInteractor
        self.profileUiConverter = profileUiConverter
        let (stream, continuation) = AsyncStream.makeStream(
            of: ProfileEffect.self,
            bufferingPolicy: .unbounded,
        )
        effects = stream
        effectsContinuation = continuation
    }

    func onIntent(_ intent: ProfileIntent) {
        switch intent {
        case .screenShown:
            loadProfile()
        case .editClicked:
            effectsContinuation.yield(.navigateToEditProfile)
        case .sharingClicked:
            effectsContinuation.yield(.navigateToSharingSettings)
        }
    }

    private func loadProfile() {
        Task {
            switch await profileInteractor.getProfile() {
            case .success(let user):
                state = .content(profileUiConverter.convert(user: user, avatarPath: nil))
                loadAvatar(user)
            case .failure(let error):
                print("ProfileViewModel: Не удалось загрузить профиль — \(error)")
                state = .error(profileUiConverter.convertError(error))
            }
        }
    }

    /// Неуспех загрузки аватара не показываем: остаёмся на плейсхолдере с инициалом.
    private func loadAvatar(_ user: User) {
        guard user.avatarVersion > 0 else { return }
        Task {
            switch await profileInteractor.getAvatar(uid: user.uid, version: user.avatarVersion) {
            case .success(let avatar):
                // Аватар обновляет avatarPath внутри .content: пользователь мог уйти
                // с вкладки за время загрузки — фаза могла смениться.
                guard case .content(let profile) = state else { return }
                var updated = profile
                updated.avatarPath = avatar.cachedPath
                state = .content(updated)
            case .failure(let error):
                print("ProfileViewModel: Не удалось загрузить аватар — \(error)")
            }
        }
    }
}
