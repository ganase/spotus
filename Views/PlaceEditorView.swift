import CoreLocation
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
                TextField("緯度", value: $latitude, format: .number.precision(.fractionLength(6)))
                    .keyboardType(.decimalPad)

                TextField("経度", value: $longitude, format: .number.precision(.fractionLength(6)))
                    .keyboardType(.decimalPad)

                Button {
                    useCurrentLocation()
                } label: {
                    Label("現在地を入力", systemImage: "location")
                }
            }

            Section("判定半径") {
                Stepper(value: $radius, in: 50...1000, step: 50) {
                    Text("\(Int(radius))m")
                }
            }
        }
        .navigationTitle(originalPlaceId == nil ? "場所を追加" : "場所を編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
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
}
