import Foundation

/// Кэш аватаров в каталоге кэша приложения: caches/avatars/{uid}_{version}.jpg.
/// Имя файла включает версию из users/{uid} (avatarVersion), поэтому после загрузки нового
/// аватара путь кэш-файла меняется и UI получает свежее изображение без ручной инвалидации.
/// Порт 1:1 из Android AvatarCache.kt.
final class AvatarCache {
    /// Подкаталог кэша приложения с аватарами.
    private static let AVATARS_DIR_NAME = "avatars"

    private var avatarsDirectory: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.AVATARS_DIR_NAME)
    }

    /// Путь к закэшированному файлу аватара; nil — файла с такой версией нет.
    func cachedPath(uid: String, version: Int) -> String? {
        let path = avatarPath(uid: uid, version: version)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Записывает байты аватара в кэш и возвращает путь к файлу;
    /// остальные кэш-файлы аватара этого пользователя удаляются (best-effort).
    func cacheBytes(uid: String, version: Int, bytes: Data) throws -> String {
        let directory = avatarsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = avatarPath(uid: uid, version: version)
        try bytes.write(to: URL(fileURLWithPath: path))
        deleteStaleCacheFiles(in: directory, keeping: path, uid: uid)
        return path
    }

    /// Удаляет прочие кэш-файлы аватара этого пользователя; сбой удаления не влияет
    /// на результат (порт Android it.delete() с игнорированием результата).
    private func deleteStaleCacheFiles(in directory: URL, keeping path: String, uid: String) {
        guard
            let contents = try? FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else {
            return
        }
        let keepingName = (path as NSString).lastPathComponent
        for item in contents
        where item.lastPathComponent != keepingName && item.lastPathComponent.hasPrefix("\(uid)_") {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private func avatarPath(uid: String, version: Int) -> String {
        avatarsDirectory.appendingPathComponent("\(uid)_\(version).jpg").path
    }
}
