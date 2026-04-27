import SwiftUI

struct SettingsView: View {
  @ObservedObject var updateCoordinator: UpdateCoordinator

  var body: some View {
    TabView {
      ConversionSettingsView()
        .tabItem {
          Label("Conversion", systemImage: "slider.horizontal.3")
        }

      UpdatesSettingsView(updateCoordinator: updateCoordinator)
        .tabItem {
          Label("Updates", systemImage: "arrow.triangle.2.circlepath")
        }
    }
    .frame(width: 480, height: 250)
  }
}
