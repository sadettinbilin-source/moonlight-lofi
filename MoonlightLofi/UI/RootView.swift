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
                    .tabItem { Label("tab.listen", systemImage: "moon.stars") }
                LibraryView()
                    .tabItem { Label("tab.library", systemImage: "music.note.list") }
                FocusView(now: timeline.date)
                    .tabItem { Label("tab.focus", systemImage: "timer") }
                YouView()
                    .tabItem { Label("tab.you", systemImage: "person") }
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
