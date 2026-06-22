import SwiftUI
import UIKit

extension View {
    /// Sets a navigation title for a tab's root view, but hides it when the iPad shows
    /// its tab bar across the top — there the tab's own label already names the screen,
    /// so a large nav title underneath is redundant. iPhone (and iPad in compact
    /// split-view multitasking, where the tab bar is at the bottom) keep the title.
    /// Any toolbar buttons are preserved either way.
    func tabNavigationTitle(_ title: String) -> some View {
        modifier(TabNavigationTitle(title: title))
    }
}

private struct TabNavigationTitle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String

    private var topTabBar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        if topTabBar {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
