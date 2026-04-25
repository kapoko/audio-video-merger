import SwiftUI

struct UpdatesSettingsView: View {
  @ObservedObject var updateCoordinator: UpdateCoordinator

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Updates")
        .font(.system(size: 18, weight: .semibold, design: .rounded))

      Toggle("Automatically check for updates", isOn: automaticallyChecksBinding)
        .disabled(!updateCoordinator.isAvailable)

      Toggle("Get beta updates", isOn: betaUpdatesBinding)
        .disabled(!updateCoordinator.isAvailable)

      Toggle("Automatically download and install updates", isOn: automaticallyDownloadsBinding)
        .disabled(
          !updateCoordinator.isAvailable || !updateCoordinator.automaticallyChecksForUpdates)

      Text(updateCoordinator.statusText)
        .font(.system(size: 13, weight: .regular, design: .rounded))
        .foregroundColor(.secondary)

      HStack {
        Spacer()

        Button("Check Now") {
          updateCoordinator.checkForUpdates()
        }
        .disabled(!updateCoordinator.isAvailable)
      }
    }
    .padding(20)
    .frame(width: 420)
  }

  private var automaticallyChecksBinding: Binding<Bool> {
    Binding(
      get: { updateCoordinator.automaticallyChecksForUpdates },
      set: { updateCoordinator.automaticallyChecksForUpdates = $0 }
    )
  }

  private var betaUpdatesBinding: Binding<Bool> {
    Binding(
      get: { updateCoordinator.betaUpdatesEnabled },
      set: { updateCoordinator.betaUpdatesEnabled = $0 }
    )
  }

  private var automaticallyDownloadsBinding: Binding<Bool> {
    Binding(
      get: { updateCoordinator.automaticallyDownloadsUpdates },
      set: { updateCoordinator.automaticallyDownloadsUpdates = $0 }
    )
  }
}
