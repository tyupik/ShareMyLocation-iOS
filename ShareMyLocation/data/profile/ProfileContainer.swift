import Factory

/// Binding data-классов профиля (аналог Android ProfileModule.kt).
/// Репозиторий и источники кэша/сжатия — синглтоны: держат файловый кэш и работу с диском.
extension Container {
    var profileRepository: Factory<ProfileRepository> {
        self {
            ProfileRepositoryImpl(
                avatarCompressor: self.avatarCompressor(),
                avatarCache: self.avatarCache(),
            )
        }.singleton
    }

    var avatarCompressor: Factory<AvatarCompressor> {
        self {
            AvatarCompressor()
        }.singleton
    }

    var avatarCache: Factory<AvatarCache> {
        self {
            AvatarCache()
        }.singleton
    }
}
