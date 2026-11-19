import CoreLocation
import GoogleMaps
import SwiftUI

/**
 Обёртка Google Maps — ЕДИНСТВЕННОЕ разрешённое место прямого UIKit-моста в проекте.
 Тёмный стиль AURORA из map_style_aurora.json (неудача — карта остаётся дефолтной),
 маркеры-аватары видимых друзей с неоновыми кольцами (diff по uid: добавить/сдвинуть/
 сменить иконку/удалить), синяя точка своего местоположения только при фактических правах,
 слежение камеры zoom 16 (без выбора — на свою точку, при выборе — за другом).
 `mapPadding` — порт contentPadding Android (GMSMapView.padding): карта рисуется
 edge-to-edge, а нативные zoom-контролы/компас/логотип Google поднимаются выше навбара.
 Слежение НЕ отменяется ручным жестом карты — как в Android (следующий тик вернёт камеру).
 Аналог GoogleMap + CameraPositionState + MapFriendMarkers Android-версии.
 */
struct AuroraMapView: UIViewRepresentable {
    let friends: [VisibleFriendUiModel]
    let selectedUid: String?
    let myLocation: MyLocationUiModel?
    let isMyLocationEnabled: Bool
    /// Отступы карты (аналог contentPadding Android): поднимают компас, логотип Google
    /// и zoom-контролы над системными insets и плавающим навбаром.
    let mapPadding: UIEdgeInsets
    let onFriendTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFriendTap: onFriendTap)
    }

    func makeUIView(context: Context) -> GMSMapView {
        // TODO: проверить на CI — GMSMapView(frame:camera:) + GMSCameraPosition.camera(withLatitude:longitude:zoom:),
        // zoom 3 — минимальный стартовый (порт Android rememberCameraPositionState по умолчанию).
        let mapView = GMSMapView(
            frame: .zero,
            camera: GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 3),
        )
        if let styleURL = Bundle.main.url(forResource: "map_style_aurora", withExtension: "json") {
            // Тёмный стиль AURORA; при неудаче чтения ресурса карта остаётся дефолтной, без краша.
            // TODO: проверить на CI — GMSMapStyle(contentsOfFileURL:).
            mapView.mapStyle = try? GMSMapStyle(contentsOfFileURL: styleURL)
        }
        // Встроенная кнопка центровки выключена — центровка через MapLocateMeButton
        // (снимает слежение), порт MapUiSettings(myLocationButtonEnabled = false) Android.
        mapView.settings.myLocationButton = false
        // TODO: проверить на CI — GMSMapView.padding (UIEdgeInsets): поднимает компас,
        // логотип Google и zoom-контролы, не сжимая саму карту (порт contentPadding Android).
        mapView.padding = mapPadding
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.apply(
            to: mapView,
            friends: friends,
            selectedUid: selectedUid,
            myLocation: myLocation,
            isMyLocationEnabled: isMyLocationEnabled,
            mapPadding: mapPadding,
        )
    }

    /**
     Coordinator карты: держит маркеры по uid, кэш ключей иконок и ключ последней
     применённой центровки камеры. Императивное API карты не Effect — живёт здесь
     (аналог CameraPositionState Android).
     */
    final class Coordinator: NSObject, GMSMapViewDelegate {
        private let onFriendTap: (String) -> Void

        /// Маркеры по uid — diff при обновлениях (маркеры не «переезжают» между uid).
        private var markersByUid: [String: GMSMarker] = [:]

        /// Последний применённый ключ иконки по uid «uid|avatarPath»:
        /// иконка пересоздаётся только при его смене (тики координат иконку не трогают).
        private var iconKeysByUid: [String: String] = [:]

        /// Ключ последней центровки камеры — animate(to:) только при его смене,
        /// иначе камера дёргалась бы на каждой эмиссии realtime-потока.
        private var lastCameraKey: CameraKey?

        init(onFriendTap: @escaping (String) -> Void) {
            self.onFriendTap = onFriendTap
        }

        /** Единая точка применения состояния (1) права/своя точка, (2) отступы, (3) маркеры, (4) камера. */
        func apply(
            to mapView: GMSMapView,
            friends: [VisibleFriendUiModel],
            selectedUid: String?,
            myLocation: MyLocationUiModel?,
            isMyLocationEnabled: Bool,
            mapPadding: UIEdgeInsets,
        ) {
            // Синяя точка своего местоположения — только при фактических грантах.
            // TODO: проверить на CI — isMyLocationEnabled без прав падает в Maps SDK.
            if mapView.isMyLocationEnabled != isMyLocationEnabled {
                mapView.isMyLocationEnabled = isMyLocationEnabled
            }
            if mapView.padding != mapPadding {
                mapView.padding = mapPadding
            }
            syncMarkers(friends: friends, mapView: mapView)
            syncCamera(mapView: mapView, friends: friends, selectedUid: selectedUid, myLocation: myLocation)
        }

        /** Diff маркеров по uid: добавить/сдвинуть/сменить иконку/удалить лишние. */
        private func syncMarkers(friends: [VisibleFriendUiModel], mapView: GMSMapView) {
            let friendsByUid = Dictionary(friends.map { ($0.uid, $0) }, uniquingKeysWith: { _, right in right })

            // Удалить маркеры друзей, переставших быть видимыми.
            let staleUids = markersByUid.keys.filter { friendsByUid[$0] == nil }
            for uid in staleUids {
                markersByUid[uid]?.map = nil
                markersByUid.removeValue(forKey: uid)
                iconKeysByUid.removeValue(forKey: uid)
            }

            for friend in friends {
                let iconKey = "\(friend.uid)|\(friend.avatarPath ?? "")"
                if let marker = markersByUid[friend.uid] {
                    // Сдвиг: тики координат двигают маркер, иконка не пересоздаётся.
                    marker.position = CLLocationCoordinate2D(
                        latitude: friend.latitude,
                        longitude: friend.longitude,
                    )
                    marker.title = friend.displayName
                    if iconKeysByUid[friend.uid] != iconKey {
                        iconKeysByUid[friend.uid] = iconKey
                        marker.icon = FriendMarkerIconFactory.icon(
                            uid: friend.uid,
                            avatarPath: friend.avatarPath,
                            displayName: friend.displayName,
                        )
                    }
                } else {
                    let marker = GMSMarker()
                    marker.position = CLLocationCoordinate2D(
                        latitude: friend.latitude,
                        longitude: friend.longitude,
                    )
                    // anchor = центр круга: координата друга в его середине, а не в нижней вершине.
                    // TODO: проверить на CI — groundAnchor.
                    marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                    marker.title = friend.displayName
                    marker.userData = friend.uid
                    iconKeysByUid[friend.uid] = iconKey
                    marker.icon = FriendMarkerIconFactory.icon(
                        uid: friend.uid,
                        avatarPath: friend.avatarPath,
                        displayName: friend.displayName,
                    )
                    marker.map = mapView
                    markersByUid[friend.uid] = marker
                }
            }
        }

        /**
         Слежение камеры: без выбранного друга — на свою точку (каждый свежий фикс даёт
         новый updatedAtMillis — повторная центровка по кнопке/автоцентровка), при выборе —
         за тиками координат друга. Ключ (selectedUid, updatedAt, lat/lng) гасит повторные
         animate на неизменном состоянии.
         */
        private func syncCamera(
            mapView: GMSMapView,
            friends: [VisibleFriendUiModel],
            selectedUid: String?,
            myLocation: MyLocationUiModel?,
        ) {
            let selectedFriend = friends.first { $0.uid == selectedUid }
            let key: CameraKey
            let target: CLLocationCoordinate2D
            if let selectedFriend {
                key = CameraKey(
                    selectedUid: selectedFriend.uid,
                    myLocationUpdatedAt: nil,
                    latitude: selectedFriend.latitude,
                    longitude: selectedFriend.longitude,
                )
                target = CLLocationCoordinate2D(
                    latitude: selectedFriend.latitude,
                    longitude: selectedFriend.longitude,
                )
            } else if let myLocation {
                key = CameraKey(
                    selectedUid: nil,
                    myLocationUpdatedAt: myLocation.updatedAtMillis,
                    latitude: nil,
                    longitude: nil,
                )
                target = CLLocationCoordinate2D(
                    latitude: myLocation.latitude,
                    longitude: myLocation.longitude,
                )
            } else {
                // Нет ни выбора, ни своего фикса — камеру не трогаем.
                return
            }
            guard key != lastCameraKey else { return }
            lastCameraKey = key
            // TODO: проверить на CI — animate(to: GMSCameraPosition.camera(withLatitude:longitude:zoom: 16)).
            mapView.animate(
                to: GMSCameraPosition.camera(
                    withLatitude: target.latitude,
                    longitude: target.longitude,
                    zoom: Self.CAMERA_ZOOM,
                ),
            )
        }

        /**
         Тап по маркеру: toggle слежения (тот же Intent, что и тап по карточке списка);
         return true — стандартное info window не показывается.
         */
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let uid = marker.userData as? String else { return false }
            onFriendTap(uid)
            return true
        }

        /// Ключ центровки камеры; nil-поля — ветка не участвует в сравнении.
        private struct CameraKey: Equatable {
            let selectedUid: String?
            let myLocationUpdatedAt: Int64?
            let latitude: Double?
            let longitude: Double?
        }

        /// Zoom камеры слежения (за другом и центровки на свою точку) — как в Android.
        private static let CAMERA_ZOOM: Float = 16
    }
}
