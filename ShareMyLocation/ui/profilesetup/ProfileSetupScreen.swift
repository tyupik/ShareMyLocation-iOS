import Factory
import PhotosUI
import SwiftUI

/// Допустимое число цифр в телефоне: экранное правило для доступности кнопки (авторитетное — в интеракторе).
private let MIN_PHONE_DIGITS = 10
private let MAX_PHONE_DIGITS = 15

/// Payload sheet'а кропа: обёртка над UIImage для sheet(item:) (эфемерное UI-состояние экрана,
/// приходит из Effect launchAvatarCrop — в state его класть запрещено правилами MVI).
private struct CropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

/**
 Экран настройки (онбординг) и редактирования профиля: один экран, isEditMode меняет только тексты.
 Навигацию выполняет вызывающая сторона через onCompleted: экран сам не знает про корневую
 навигацию, лямбда вызывается только из коллекции Effect. Порт Android ProfileSetupScreen.kt;
 iOS-адаптации этапа 3: photo picker — PhotosPicker, камера — sheet ProfileCameraPicker,
 кроп — sheet MantisCropView.
 */
struct ProfileSetupScreen: View {
    let isEditMode: Bool
    let onCompleted: () -> Void

    @State private var viewModel: ProfileSetupViewModel

    /// Снимок, ожидающий Mantis-кропа (из Effect launchAvatarCrop).
    @State private var cropPayload: CropPayload?

    /// Выбранное в PhotosPicker изображение.
    @State private var pickerItem: PhotosPickerItem?

    init(isEditMode: Bool, onCompleted: @escaping () -> Void) {
        self.isEditMode = isEditMode
        self.onCompleted = onCompleted
        _viewModel = State(initialValue: Container.shared.profileSetupViewModel())
    }

    var body: some View {
        ProfileSetupContent(
            state: viewModel.state,
            isEditMode: isEditMode,
            onIntent: { viewModel.onIntent($0) },
        )
        .task {
            // На каждый показ — перечитка профиля (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown)
        }
        .task {
            for await effect in viewModel.effects {
                switch effect {
                case .completed:
                    onCompleted()
                case .launchAvatarCrop(let image):
                    cropPayload = CropPayload(image: image)
                }
            }
        }
        .photosPicker(
            isPresented: Binding(
                get: { viewModel.state.isGalleryPickerPresented },
                set: { newValue in
                    // Закрытие пикера (в том числе после выбора) — сброс флага состояния.
                    if !newValue {
                        viewModel.onIntent(.avatarGalleryDismissed)
                    }
                },
            ),
            selection: $pickerItem,
            matching: .images,
        )
        .onChange(of: pickerItem) { _, newItem in
            // TODO: проверить на CI — loadTransferable(type: Data.self) в PhotosUI (iOS 17).
            guard let newItem else { return }
            Task {
                let data = try? await newItem.loadTransferable(type: Data.self)
                viewModel.onIntent(.avatarPicked(data))
                pickerItem = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.isCameraPresented },
            set: { newValue in
                // Закрытие sheet камеры (отмена/свайп) — отмена съёмки во ViewModel.
                if !newValue {
                    viewModel.onIntent(.avatarCaptureCancelled)
                }
            },
        )) {
            ProfileCameraPicker(
                onCaptureCompleted: { viewModel.onIntent(.avatarCaptureCompleted($0)) },
                onCancelled: { viewModel.onIntent(.avatarCaptureCancelled) },
            )
        }
        .sheet(item: $cropPayload) { payload in
            MantisCropView(
                image: payload.image,
                onCropped: { viewModel.onIntent(.avatarCropConfirmed($0)) },
                onCancelled: { viewModel.onIntent(.avatarCropCancelled) },
            )
        }
    }
}

/// Контент экрана: производные флаги валидности и тексты ошибок считаются здесь,
/// а не в ViewModel (чистый UI-расчёт, порт ProfileSetupContent Android).
private struct ProfileSetupContent: View {
    let state: ProfileSetupUiState
    let isEditMode: Bool
    let onIntent: (ProfileSetupIntent) -> Void

    var body: some View {
        if state.isLoading {
            ProgressView()
                .tint(AuroraColors.auroraIndigoLight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AuroraBackdrop {
                form
            }
            ProfileSetupAvatarSourceDialog(
                isPresented: Binding(
                    get: { state.isAvatarSourceDialogVisible },
                    set: { newValue in
                        if !newValue {
                            onIntent(.avatarSourceDialogDismissed)
                        }
                    },
                ),
                onGallerySelected: { onIntent(.avatarSourceGallerySelected) },
                onCameraSelected: { onIntent(.avatarSourceCameraSelected) },
            )
        }
    }

    private var form: some View {
        // Кнопка активна, только если форма заполнена (чистый UI-расчёт, не бизнес-состояние).
        // Подсчёт цифр — тот же ASCII-фильтр PhoneNormalizer, что и в интеракторе,
        // чтобы экранное правило совпадало с авторитетной валидацией.
        let isPhoneValid = (MIN_PHONE_DIGITS...MAX_PHONE_DIGITS).contains(PhoneNormalizer.digitCount(state.phone))
        let isFormValid = !state.displayName.trimmingCharacters(in: .whitespaces).isEmpty && isPhoneValid

        let bannerErrorText: String?
        switch state.error {
        case .some(.network):
            bannerErrorText = "Не удалось сохранить профиль. Проверьте интернет и попробуйте снова"
        case .some(.avatarTooLarge):
            bannerErrorText = "Не удалось сохранить фото: оно слишком большое"
        case .some(.cameraUnavailable):
            bannerErrorText = "Не удалось открыть камеру. Убедитесь, что на устройстве есть приложение камеры"
        case .some(.unexpected):
            bannerErrorText = "Не удалось сохранить профиль. Попробуйте ещё раз"
        case .some(.invalidPhone), .none:
            bannerErrorText = nil
        }

        let phoneErrorText: String?
        if case .some(.invalidPhone) = state.error {
            phoneErrorText = "Телефон должен содержать от 10 до 15 цифр"
        } else {
            phoneErrorText = nil
        }

        return ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                if let bannerErrorText {
                    ProfileSetupErrorBanner(
                        text: bannerErrorText,
                        onDismiss: { onIntent(.errorDismissed) },
                    )
                }

                Text(isEditMode ? "Редактирование профиля" : "Настройка профиля")
                    .font(.auroraHeadlineMedium)
                    .tracking(AuroraTypography.HEADLINE_TRACKING)
                    .foregroundStyle(AuroraColors.auroraText)

                ProfileSetupAvatarPicker(
                    displayName: state.displayName,
                    savedAvatarPath: state.savedAvatarPath,
                    localPath: state.pendingAvatarPath,
                    isEnabled: !state.isSaving,
                    isEditMode: isEditMode,
                    onPickRequest: { onIntent(.avatarPickRequested) },
                )

                ProfileSetupNameField(
                    text: Binding(
                        get: { state.displayName },
                        set: { onIntent(.displayNameChanged($0)) },
                    ),
                    isEnabled: !state.isSaving,
                )

                ProfileSetupPhoneField(
                    text: Binding(
                        get: { state.phone },
                        set: { onIntent(.phoneChanged($0)) },
                    ),
                    isEnabled: !state.isSaving,
                    errorText: phoneErrorText,
                )

                ProfileSetupSaveButton(
                    title: isEditMode ? "Сохранить" : "Готово",
                    isEnabled: isFormValid,
                    isLoading: state.isSaving,
                ) {
                    onIntent(.saveClicked)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    ProfileSetupContent(state: .initial, isEditMode: false, onIntent: { _ in })
        .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
