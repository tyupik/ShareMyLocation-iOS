import SwiftUI

/**
 Inline-состояние упавшего realtime-потока карты: стеклянная карточка со строкой ошибки
 и «Повторить» (= screenShown — перезапуск потока и перечитка настроек/групп).
 Порт 1:1 из Android MapLoadError.kt (строки map_load_error/map_retry — дословно).
 */
struct MapLoadError: View {
    let onRetry: () -> Void

    var body: some View {
        GlassCard {
            LoadError(
                text: "Не удалось загрузить карту. Проверьте интернет и попробуйте снова",
                retryText: "Повторить",
                onRetry: onRetry,
            )
            .padding(16)
        }
    }
}

#Preview {
    MapLoadError(onRetry: {})
        .padding(24)
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
