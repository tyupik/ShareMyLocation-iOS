import ContactsUI
import SwiftUI

/**
 Обёртка над CNContactPickerViewController (UIViewControllerRepresentable):
 системный пикер контактов, не требующий разрешений (iOS-аналог ACTION_PICK Android).
 Делегат didSelect отдаёт выбранный контакт целиком, didCancel — закрытие без выбора
 (onContactPicked(nil)). Единственное в фиче место прямого UIKit-моста (разрешено
 наравне с обёрткой карты — пикер из утверждённого стека, ContactsUI).
 */
struct ContactsPickerView: UIViewControllerRepresentable {
    /// Контакт или nil (закрыто без выбора) — порт ContactPicked(contactUri: String?) Android.
    let onContactPicked: (CNContact?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactPicked: onContactPicked)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onContactPicked: (CNContact?) -> Void

        init(onContactPicked: @escaping (CNContact?) -> Void) {
            self.onContactPicked = onContactPicked
        }

        // TODO: проверить на CI — вызов didSelect/didCancel у CNContactPickerDelegate
        // внутри SwiftUI-sheet (контакт приходит целиком, разрешение не запрашивается).
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactPicked(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onContactPicked(nil)
        }
    }
}
