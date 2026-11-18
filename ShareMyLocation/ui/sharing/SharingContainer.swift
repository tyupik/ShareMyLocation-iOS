import Factory

/// Binding ui-классов настроек шаринга. ViewModel не singleton: время жизни — показ sheet'а,
/// на каждый показ создаётся новый экземпляр (паттерн GroupEditorContainer).
extension Container {
    var sharingSettingsViewModel: Factory<SharingSettingsViewModel> {
        self {
            SharingSettingsViewModel(
                sharingInteractor: self.sharingInteractor(),
                friendsInteractor: self.friendsInteractor(),
                groupsInteractor: self.groupsInteractor(),
                locationPermissionRequester: self.locationPermissionRequester(),
                sharingSettingsUiConverter: self.sharingSettingsUiConverter(),
            )
        }
    }

    var sharingSettingsUiConverter: Factory<SharingSettingsUiConverter> {
        self {
            SharingSettingsUiConverter()
        }
    }
}
