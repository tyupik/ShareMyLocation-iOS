import SwiftUI

/// Диалог выбора источника аватара: галерея или камера.
/// iOS-адаптация Android ProfileSetupAvatarSourceDialog.kt (AlertDialog → confirmationDialog);
/// рисуется невидимой точкой-якорем, презентация управляется state-флагом экрана.
struct ProfileSetupAvatarSourceDialog: View {
    @Binding var isPresented: Bool
    let onGallerySelected: () -> Void
    let onCameraSelected: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .confirmationDialog(
                "Выбор фото",
                isPresented: $isPresented,
                titleVisibility: .visible,
            ) {
                Button("Выбрать из галереи", action: onGallerySelected)
                Button("Сделать фото", action: onCameraSelected)
                Button("Отмена", role: .cancel) {}
            }
    }
}

#Preview {
    ProfileSetupAvatarSourceDialog(isPresented: .constant(false), onGallerySelected: {}, onCameraSelected: {})
}
