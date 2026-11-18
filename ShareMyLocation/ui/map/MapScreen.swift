import Factory
import SwiftUI

/**
 Вкладка «Карта»: GoogleMap с аватар-маркерами видимых друзей, синей точкой своего
 местоположения (только при фактических правах), кнопкой центровки и чипом списка
 с bottom-sheet'ом. Перечитывание при показе вкладки — через MapIntent.screenShown.
 Сбор Effect: запрос системного диалога прав геолокации (ВНУТРЕННИЙ Task — ожидание
 диалога не блокирует цикл эффектов), результат — intent'ом locationPermissionsResult.
 Слежение камеры — производная состояния, живёт в Coordinator AuroraMapView (императивное
 API карты не Effect). Без настроенного API-ключа карту не инициализируем вовсе —
 заглушка. Порт 1:1 из Android MapScreen.kt.
 */
struct MapScreen: View {
    @State private var viewModel: MapViewModel

    init() {
        _viewModel = State(initialValue: Container.shared.mapViewModel())
    }

    var body: some View {
        AuroraBackdrop {
            MapContent(
                state: viewModel.state,
                onIntent: { viewModel.onIntent($0) },
            )
        }
        .task {
            // На каждый показ — перезапуск realtime-потоков и перечитка прав
            // (порт LaunchedEffect(Unit) Android).
            viewModel.onIntent(.screenShown)
        }
        .task {
            // Гонка «вкладка сменилась, Task прав ждёт решения»: отправка
            // .locationPermissionsResult в умирающую ViewModel безвредна — состояние
            // больше никому не показывается (паттерн SharingSettingsScreen).
            for await effect in viewModel.effects {
                switch effect {
                case .requestLocationPermissions:
                    // ВНУТРЕННИЙ Task (fire-and-forget): ожидание системного диалога
                    // НЕ блокирует цикл эффектов.
                    Task {
                        let requester = Container.shared.locationPermissionRequester()
                        let granted = await requester.requestWhenInUse()
                        viewModel.onIntent(.locationPermissionsResult(granted: granted))
                    }
                }
            }
        }
    }
}

/// Контент вкладки: карта + плавающие элементы. Порт MapContent Android
/// (зазоры кнопок упрощены — этап 9 подгонит edge-to-edge и отступы).
private struct MapContent: View {
    let state: MapUiState
    let onIntent: (MapIntent) -> Void

    var body: some View {
        ZStack {
            if MapApiKey.isConfigured {
                // Без ключа карту не инициализируем вовсе: Maps SDK падает на старте.
                AuroraMapView(
                    friends: state.visibleFriends,
                    selectedUid: state.selectedUid,
                    myLocation: state.myLocation,
                    isMyLocationEnabled: state.hasLocationPermission,
                    onFriendTap: { uid in onIntent(.friendSelected(uid: uid)) },
                )
                // Кнопка видна и без прав: тап без прав запрашивает их (порт Android —
                // LocateMeClicked гейтит права внутри ViewModel). Синяя точка при этом
                // гейтится фактическими грантами через isMyLocationEnabled.
                MapLocateMeButton(onClick: { onIntent(.locateMeClicked) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 8)
                    .padding(.bottom, Self.LOCATE_BUTTON_BOTTOM_GAP)
            } else {
                MapUnavailableNotice()
            }
            if state.isMapLoading && !state.isMapLoadFailed {
                ProgressView()
                    .tint(AuroraColors.auroraIndigoLight)
            }
            if state.isMapLoadFailed {
                MapLoadError(onRetry: { onIntent(.screenShown) })
                    .padding(.horizontal, 24)
            }
            if !state.visibleFriends.isEmpty {
                MapOpenListButton(
                    visibleCount: state.visibleFriends.count,
                    onClick: { onIntent(.showListClicked) },
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.LIST_BUTTON_BOTTOM_GAP)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { state.isListVisible },
                set: { newValue in
                    // Закрытие sheet'а (свайп, тап вне) — сброс флага состояния.
                    if !newValue {
                        onIntent(.listDismissed)
                    }
                },
            ),
        ) {
            MapFriendsListSheet(
                friends: state.visibleFriends,
                onFriendClick: { uid in onIntent(.friendSelected(uid: uid)) },
            )
        }
    }

    /// Зазор кнопки центровки над стеком нативных zoom-контролов Google (упрощение до этапа 9).
    private static let LOCATE_BUTTON_BOTTOM_GAP: CGFloat = 132

    /// Зазор чипа «На карте: N» над нижним краем карты (упрощение до этапа 9).
    private static let LIST_BUTTON_BOTTOM_GAP: CGFloat = 28
}

#Preview {
    MapContent(
        state: MapUiState.initial,
        onIntent: { _ in },
    )
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
