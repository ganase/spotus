import CoreLocation
import MapKit
import SwiftUI

struct PlaceEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let originalPlaceId: UUID?

    @State private var name: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var radius: Double
    @State private var category: PlaceCategory
    @State private var isEnabled: Bool
    @State private var isMapPickerPresented = false

    init(place: Place?) {
        originalPlaceId = place?.id
        _name = State(initialValue: place?.name ?? "")
        _latitude = State(initialValue: place?.latitude ?? 35.681236)
        _longitude = State(initialValue: place?.longitude ?? 139.767125)
        _radius = State(initialValue: place?.radius ?? 150)
        _category = State(initialValue: place?.category ?? .station)
        _isEnabled = State(initialValue: place?.isEnabled ?? true)
    }

    var body: some View {
        Form {
            Section("基本情報") {
                TextField("場所名", text: $name)

                Picker("カテゴリ", selection: $category) {
                    ForEach(PlaceCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.systemImage)
                            .tag(category)
                    }
                }

                Toggle("有効", isOn: $isEnabled)
            }

            Section("座標") {
                PlaceCoordinatePreview(
                    name: displayName,
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                    category: category
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    useCurrentLocation()
                } label: {
                    Label("現在地を入力", systemImage: "location")
                }

                Button {
                    isMapPickerPresented = true
                } label: {
                    Label("地図で指定", systemImage: "map")
                }

                LabeledContent("緯度", value: latitude.formatted(.number.precision(.fractionLength(6))))
                LabeledContent("経度", value: longitude.formatted(.number.precision(.fractionLength(6))))
            }

            Section("判定半径") {
                Stepper(value: $radius, in: 50...1000, step: 50) {
                    Text("\(Int(radius))m")
                }
            }

            Section {
                EditorActionBar(
                    canSave: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onSave: {
                        save()
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            }
        }
        .themedScreenBackground()
        .navigationTitle(originalPlaceId == nil ? "場所を追加" : "場所を編集")
        .sheet(isPresented: $isMapPickerPresented) {
            MapCoordinatePickerView(
                name: displayName,
                latitude: $latitude,
                longitude: $longitude,
                radius: radius,
                category: category
            )
            .environmentObject(appState)
        }
    }

    private func useCurrentLocation() {
        if let coordinate = appState.locationService.lastKnownLocation?.coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        } else {
            appState.requestCurrentLocation()
        }
    }

    private func save() {
        let place = Place(
            id: originalPlaceId ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            category: category,
            isEnabled: isEnabled
        )

        if originalPlaceId == nil {
            appState.addPlace(place)
        } else {
            appState.updatePlace(place)
        }

        dismiss()
    }

    private var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "指定地点" : trimmedName
    }
}

private struct PlaceCoordinatePreview: View {
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let category: PlaceCategory

    var body: some View {
        Map {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            MapCircle(center: coordinate, radius: radius)
                .foregroundStyle(Color.accentColor.opacity(0.14))
                .stroke(Color.accentColor, lineWidth: 1)

            Marker(name, systemImage: category.systemImage, coordinate: coordinate)
        }
        .allowsHitTesting(false)
    }
}

private struct MapCoordinatePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let name: String
    @Binding var latitude: Double
    @Binding var longitude: Double
    let radius: Double
    let category: PlaceCategory

    @State private var position: MapCameraPosition

    init(
        name: String,
        latitude: Binding<Double>,
        longitude: Binding<Double>,
        radius: Double,
        category: PlaceCategory
    ) {
        self.name = name
        _latitude = latitude
        _longitude = longitude
        self.radius = radius
        self.category = category

        let coordinate = CLLocationCoordinate2D(latitude: latitude.wrappedValue, longitude: longitude.wrappedValue)
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: max(radius * 5, 700),
                longitudinalMeters: max(radius * 5, 700)
            )
        ))
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()

                    MapCircle(center: selectedCoordinate, radius: radius)
                        .foregroundStyle(Color.accentColor.opacity(0.16))
                        .stroke(Color.accentColor, lineWidth: 2)

                    Marker(name, systemImage: category.systemImage, coordinate: selectedCoordinate)
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                            latitude = coordinate.latitude
                            longitude = coordinate.longitude
                            position = .region(
                                MKCoordinateRegion(
                                    center: coordinate,
                                    latitudinalMeters: max(radius * 5, 700),
                                    longitudinalMeters: max(radius * 5, 700)
                                )
                            )
                        }
                )
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("地図をタップして地点を指定")
                        .font(.headline)
                    Text("\(latitude.formatted(.number.precision(.fractionLength(6)))), \(longitude.formatted(.number.precision(.fractionLength(6))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        useCurrentLocation()
                    } label: {
                        Label("現在地に合わせる", systemImage: "location")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("地図で指定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var selectedCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func useCurrentLocation() {
        if let coordinate = appState.locationService.lastKnownLocation?.coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            position = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: max(radius * 5, 700),
                    longitudinalMeters: max(radius * 5, 700)
                )
            )
        } else {
            appState.requestCurrentLocation()
        }
    }
}
