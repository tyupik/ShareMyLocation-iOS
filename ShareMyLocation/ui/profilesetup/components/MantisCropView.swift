import Mantis
import SwiftUI

/// Обёртка Mantis-кропа над sheet'ем экрана настройки профиля: круглое кадрирование
/// (порт CropImageContract Android: OVAL + 1:1, встроенные источники отключены —
/// фото приходит из галереи/камеры через Effect launchAvatarCrop).
struct MantisCropView: UIViewControllerRepresentable {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancelled: () -> Void

    func makeUIViewController(context: Context) -> CropViewController {
        // TODO: проверить на CI — сигнатуры Mantis.Config, cropShapeType = .circle(maskType:)
        // и фабрики Mantis.cropViewController(image:config:) в Mantis 2.18+.
        var config = Mantis.Config()
        config.cropShapeType = .circle(maskType: .default)
        let cropViewController = Mantis.cropViewController(image: image, config: config)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCropped: onCropped,
            onCancelled: onCancelled,
        )
    }

    /// Мост делегата Mantis в лямбды экрана; закрытие sheet выполняет экран.
    final class Coordinator: NSObject, CropViewControllerDelegate {
        private let onCropped: (UIImage) -> Void
        private let onCancelled: () -> Void

        init(onCropped: @escaping (UIImage) -> Void, onCancelled: @escaping () -> Void) {
            self.onCropped = onCropped
            self.onCancelled = onCancelled
        }

        // TODO: проверить на CI — сигнатуры делегата CropViewControllerDelegate в Mantis 2.18+
        // (cropViewControllerDidCrop(_:cropped:transformation:cropInfo:),
        // cropViewControllerDidCancel(_:original:)).
        func cropViewControllerDidCrop(
            _ cropViewController: CropViewController,
            cropped: UIImage,
            transformation: Transformation,
            cropInfo: CropInfo,
        ) {
            onCropped(cropped)
        }

        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            onCancelled()
        }
    }
}
