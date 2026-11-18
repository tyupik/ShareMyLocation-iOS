import SwiftUI
import UIKit

/// Обёртка системной камеры (UIImagePickerController) над sheet'ем экрана настройки профиля.
/// Порт CameraAvatarSource + TakePicture из Android: снимок возвращается UIImage
/// в onCaptureCompleted, отмена — onCancelled; закрытие sheet выполняет экран
/// через state-флаг isCameraPresented.
struct ProfileCameraPicker: UIViewControllerRepresentable {
    let onCaptureCompleted: (UIImage) -> Void
    let onCancelled: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Доступность камеры проверяет ViewModel (isCameraAvailable) до открытия sheet.
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCaptureCompleted: onCaptureCompleted,
            onCancelled: onCancelled,
        )
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCaptureCompleted: (UIImage) -> Void
        private let onCancelled: () -> Void

        init(onCaptureCompleted: @escaping (UIImage) -> Void, onCancelled: @escaping () -> Void) {
            self.onCaptureCompleted = onCaptureCompleted
            self.onCancelled = onCancelled
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any],
        ) {
            // TODO: проверить на CI — info[.originalImage] as? UIImage в UIImagePickerControllerDelegate.
            if let image = info[.originalImage] as? UIImage {
                onCaptureCompleted(image)
            } else {
                onCancelled()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancelled()
        }
    }
}
