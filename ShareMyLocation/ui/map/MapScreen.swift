import Factory
import SwiftUI
import UIKit

/**
 Вкладка «Карта»: GoogleMap с аватар-маркерами видимых друзей, синей точкой своего
 местоположения (только при фактических правах), кнопкой центровки и чипом списка
 с bottom-sheet'ом. Перечитывание при показе вкладки — через MapIntent.screenShown.
 Сбор Effect: запрос системного диалога прав геолокации (ВНУТРЕННИЙ Task — ожидание
 диалога не блокирует цикл эффектов), результат — intent'ом locationPermissionsResult.
 Слежение камеры — производная состояния, живёт в Coordinator AuroraMapView (императивное
 API карты не Effect). Без настроенного API-ключа карту не инициализируем вовсе —
 заглушка. Карта edge-to-edge: системные отступы и место под плавающий навбар приходят
 через mapPadding (порт contentPadding Android), AuroraBackdrop у карты нет —
 Android-свечения на вкладке «Карта» тоже нет, фон даёт корень. Порт 1:1 из Android MapScreen.kt.
 */
struct MapScreen: View {
    @State private var viewModel: MapViewModel

    init() {
        _viewModel = State(initialValue: Container.shared.mapViewModel())
    }

    var body: some View {
        MapContent(
            state: viewModel.state,
            onIntent: { viewModel.onIntent($0) },
        )
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

/// Контент вкладки: карта edge-to-edge + плавающие элементы (порт MapContent Android).
private struct MapContent: View {
    let state: MapUiState
    let onIntent: (MapIntent) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if MapApiKey.isConfigured {
                    // Без ключа карту не инициализируем вовсе: Maps SDK падает на старте.
                    AuroraMapView(
                        friends: state.visibleFriends,
                        selectedUid: state.selectedUid,
                        myLocation: state.myLocation,
                        isMyLocationEnabled: state.hasLocationPermission,
                        mapPadding: UIEdgeInsets(
                            top: proxy.safeAreaInsets.top,
                            left: 0,
                            right: 0,
                            bottom: proxy.safeAreaInsets.bottom + Self.MAP_BOTTOM_CLEARANCE,
                        ),
                        onFriendTap: { uid in onIntent(.friendSelected(uid: uid)) },
                    )
                    .ignoresSafeArea()
                    // Кнопка видна и без прав: тап без прав запрашивает их (порт Android —
                    // LocateMeClicked гейтит права внутри ViewModel). Синяя точка при этом
                    // гейтится фактическими грантами через isMyLocationEnabled.
                    MapLocateMeButton(onClick: { onIntent(.locateMeClicked) })
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 8)
                        .padding(
                            .bottom,
                            proxy.safeAreaInsets.bottom + Self.MAP_BOTTOM_CLEARANCE + Self.LOCATE_BUTTON_BOTTOM_GAP,
                        )
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
                    .padding(
                        .bottom,
                        proxy.safeAreaInsets.bottom + Self.MAP_BOTTOM_CLEARANCE + Self.LIST_BUTTON_BOTTOM_GAP,
                    )
                }
            }
        }
        .ignoresSafeArea()
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

    /**
     Добавка к bottom у mapPadding/кнопок: safeAreaInsets.bottom уже содержит пилюлю-навбар
     (safeAreaInset в MainScreen расширяет safe area, как navigationBars+пилюля Android),
     поэтому от Android NAVBAR_CLEARANCE = 96 остаётся только зазор 16. Итог ≈34 (дом-полоса)
     + ~90 (пилюля) + 16 ≈ 140pt — совпадает с Android 144dp.
     */
    private static let MAP_BOTTOM_CLEARANCE: CGFloat = 16

    /// Зазор кнопки центровки над стеком нативных zoom-контролов Google
    /// (~48dp x 2 от низа ~10–12dp, верх ≈ 106–116dp) с запасом ≥ 16dp.
    private static let LOCATE_BUTTON_BOTTOM_GAP: CGFloat = 132

    /// Зазор чипа «На карте: N» над нижним краем карты.
    private static let LIST_BUTTON_BOTTOM_GAP: CGFloat = 28
}

#Preview {
    MapContent(
        state: MapUiState.initial,
        onIntent: { _ in },
    )
    .background(AuroraColors.auroraBackground.ignoresSafeArea())
}
