import Factory

/// Binding ui-классов вкладки «Друзья». ViewModel не singleton: время жизни — экран
/// (паттерн создания из AGENTS.md: State(initialValue: Container.shared.friendsViewModel())).
extension Container {
    var friendsViewModel: Factory<FriendsViewModel> {
        self {
            FriendsViewModel(
                friendsInteractor: self.friendsInteractor(),
                contactsInteractor: self.contactsInteractor(),
                groupsInteractor: self.groupsInteractor(),
                profileInteractor: self.profileInteractor(),
                friendsUiConverter: self.friendsUiConverter(),
            )
        }
    }

    var friendsUiConverter: Factory<FriendsUiConverter> {
        self {
            FriendsUiConverter()
        }
    }
}
