import SwiftUI

struct PlaceListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isAddingPlace = false

    var body: some View {
        List {
            Section {
                ForEach(appState.places) { place in
                    NavigationLink {
                        PlaceEditorView(place: place)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: place.category.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                    .font(.headline)
                                Text("\(place.category.displayName) / 半径 \(Int(place.radius))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: binding(for: place))
                                .labelsHidden()
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            appState.testEnterTrigger(for: place)
                        } label: {
                            Label("テスト", systemImage: "bell")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: appState.deletePlaces)
            } footer: {
                Text("iOSのRegion Monitoringは同時監視数に上限があります。MVPでは有効な地点の先頭20件を登録します。")
            }
        }
        .navigationTitle("Place")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingPlace = true
                } label: {
                    Label("追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingPlace) {
            NavigationStack {
                PlaceEditorView(place: nil)
            }
        }
    }

    private func binding(for place: Place) -> Binding<Bool> {
        Binding(
            get: {
                appState.places.first(where: { $0.id == place.id })?.isEnabled ?? false
            },
            set: { isEnabled in
                appState.setPlaceEnabled(place.id, isEnabled: isEnabled)
            }
        )
    }
}
