/// Ui-модели и конвертер вкладки «Друзья»: порт 1:1 из Android FriendsUiConverter.kt.

/// Ui-модель друга/найденного пользователя: `avatarPath` резолвится асинхронно.
struct FriendUiModel {
    let uid: String
    let displayName: String
    let phone: String?
    let avatarVersion: Int
    var avatarPath: String?
}

/// Ui-модель входящей заявки: `avatarPath` резолвится асинхронно.
/// Порт 1:1 из Android FriendRequestUiModel.
struct FriendRequestUiModel {
    let fromUid: String
    let fromName: String
    let fromAvatarVersion: Int
    var avatarPath: String?
}

/// Ui-модель группы в секции «Группы»: карточка показывает имя и число участников.
/// Порт 1:1 из Android GroupUiModel.
struct GroupUiModel {
    let groupId: String
    let name: String
    let memberCount: Int
}

/// Ошибки фичи «Друзья» в терминах Ui-слоя. Порт 1:1 из Android FriendsUiError.
enum FriendsUiError {
    case network
    case invalidPhone
    case requestToSelf
    case alreadyFriends
    case requestAlreadySent
    case requestAlreadyIncoming

    /// У выбранного из контактов друга нет телефона.
    case contactNoPhone

    /// Не удалось прочитать выбранный контакт.
    case contactReadFailed

    case unexpected(String?)
}

/// Конвертер бизнес-моделей друзей в Ui-модели вкладки «Друзья». Порт 1:1 из Android.
struct FriendsUiConverter {
    /// `avatarPath` заполняется ViewModel после дозагрузки аватара.
    func convertFriend(_ user: User) -> FriendUiModel {
        FriendUiModel(
            uid: user.uid,
            displayName: user.displayName ?? "",
            phone: user.phone,
            avatarVersion: user.avatarVersion,
            avatarPath: nil,
        )
    }

    /// `avatarPath` заполняется ViewModel после дозагрузки аватара.
    func convertRequest(_ request: FriendRequest) -> FriendRequestUiModel {
        FriendRequestUiModel(
            fromUid: request.fromUid,
            fromName: request.fromName,
            fromAvatarVersion: request.fromAvatarVersion,
            avatarPath: nil,
        )
    }

    /// Имена участников на вкладке не нужны — только их число.
    func convertGroup(_ group: Group) -> GroupUiModel {
        GroupUiModel(
            groupId: group.groupId,
            name: group.name,
            memberCount: group.memberUids.count,
        )
    }

    func convertError(_ error: FriendsError) -> FriendsUiError {
        switch error {
        case .networkUnavailable:
            return .network
        case .invalidPhone:
            return .invalidPhone
        case .requestToSelf:
            return .requestToSelf
        case .alreadyFriends:
            return .alreadyFriends
        case .requestAlreadySent:
            return .requestAlreadySent
        case .requestAlreadyIncoming:
            return .requestAlreadyIncoming
        case .unexpected(let reason):
            return .unexpected(reason)
        case .userNotFound:
            // UserNotFound обрабатывается отдельно (не найдено), сюда попадает как Unexpected.
            return .unexpected("FriendsError.userNotFound")
        }
    }

    /// Ошибки чтения телефонной книги попадают в тот же баннер действия, что и ошибки друзей.
    func convertContactError(_ error: ContactsError) -> FriendsUiError {
        switch error {
        case .noPhone:
            return .contactNoPhone
        case .readFailed:
            return .contactReadFailed
        }
    }
}
