import SwiftUI

extension View {
    func onScenePhaseActive(perform action: @escaping () -> Void) -> some View {
        modifier(ScenePhaseActiveModifier(action: action))
    }
}

private struct ScenePhaseActiveModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { action() }
        }
    }
}
