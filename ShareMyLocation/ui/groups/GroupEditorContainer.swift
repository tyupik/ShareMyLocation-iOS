import Factory

/// Binding ui-классов редактора группы. ViewModel не singleton: время жизни — показ sheet'а,
/// на каждый показ создаётся новый экземпляр (заодно снимает Android-риск stale Closed).
extension Container {
    var groupEditorViewModel: Factory<GroupEditorViewModel> {
        self {
            GroupEditorViewModel(
                groupsInteractor: self.groupsInteractor(),
                friendsInteractor: self.friendsInteractor(),
                groupEditorUiConverter: self.groupEditorUiConverter(),
            )
        }
    }

    var groupEditorUiConverter: Factory<GroupEditorUiConverter> {
        self {
            GroupEditorUiConverter()
        }
    }
}
