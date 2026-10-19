import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            TabView {
                NowView(now: timeline.date)
                    .accessibilityElement(children: .contain)
                    .background { screenMarker("screen.listen") }
                    .tabItem {
                        Label("tab.listen", systemImage: "moon.stars")
                            .accessibilityIdentifier("tab.listen")
                    }
                LibraryView()
                    .accessibilityElement(children: .contain)
                    .background { screenMarker("screen.library") }
                    .tabItem {
                        Label("tab.library", systemImage: "music.note.list")
                            .accessibilityIdentifier("tab.library")
                    }
                FocusView(now: timeline.date)
                    .accessibilityElement(children: .contain)
                    .background { screenMarker("screen.focus") }
                    .tabItem {
                        Label("tab.focus", systemImage: "timer")
                            .accessibilityIdentifier("tab.focus")
                    }
                YouView()
                    .accessibilityElement(children: .contain)
                    .background { screenMarker("screen.you") }
                    .tabItem {
                        Label("tab.you", systemImage: "person")
                            .accessibilityIdentifier("tab.you")
                    }
            }
            .background(Tick(date: timeline.date))
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.night)
        }
        .sheet(isPresented: $model.showSleep) {
            SleepSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.night)
        }
        .fullScreenCover(isPresented: $model.showDark) {
            DarkScreen()
        }
        .alert(
            Text("error.title"),
            isPresented: Binding(
                get: { model.alertKey != nil },
                set: { if !$0 { model.alertKey = nil } }
            )
        ) {
            Button("alert.ok", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(model.alertKey ?? "error.playback"))
        }
        .onAppear {
            model.attach(context: modelContext)
            model.focus.tick(now: Date())
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.focus.tick(now: Date())
            model.playback.reconcileSleep()
        }
        .onChange(of: model.store.isPro) { _, _ in
            model.focus.persist()
        }
    }
}

private func screenMarker(_ identifier: String) -> some View {
    Color.clear
        .frame(width: 1, height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
}

private struct Tick: View {
    @Environment(AppModel.self) private var model
    var date: Date

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: date) { _, newDate in
                model.focus.tick(now: newDate)
                model.playback.reconcileSleep(now: newDate)
            }
    }
}
