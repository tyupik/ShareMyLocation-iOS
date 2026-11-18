import SwiftUI

/**
 Экран-ошибка первичной загрузки редактора (группа не прочитана или упал поток друзей):
 текст причины и «Повторить» — повторный screenShown.
 */
struct GroupEditorLoadError: View {
    let text: String
    let onRetry: () -> Void

    var body: some View {
        LoadError(text: text, retryText: "Повторить", onRetry: onRetry, isCentered: true)
    }
}
