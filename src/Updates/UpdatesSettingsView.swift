import SwiftUI

struct UpdatesSettingsView: View {
  @ObservedObject var updateCoordinator: UpdateCoordinator

  var body: some View {
    Form {
      Section {
        SettingsToggleRow(
          icon: "arrow.triangle.2.circlepath",
          title: "Automatically check for updates",
          isOn: automaticallyChecksBinding
        ).disabled(!updateCoordinator.isAvailable)

        HStack {
          Text(updateCoordinator.statusText)
            .font(.caption)
            .foregroundStyle(.secondary)

          Spacer()

          Button("Check Now") {
            updateCoordinator.checkForUpdates()
          }
          .disabled(!updateCoordinator.isAvailable)

        }
      }

      Section {
        SettingsToggleRow(
          icon: "square.and.arrow.down",
          title: "Automatically download and install updates",
          isOn: automaticallyDownloadsBinding
        )
        .disabled(
          !updateCoordinator.isAvailable || !updateCoordinator.automaticallyChecksForUpdates)
      }

    }
    .formStyle(.grouped)
  }

  private var automaticallyChecksBinding: Binding<Bool> {
    Binding(
      get: { updateCoordinator.automaticallyChecksForUpdates },
      set: { updateCoordinator.automaticallyChecksForUpdates = $0 }
    )
  }

  private var automaticallyDownloadsBinding: Binding<Bool> {
    Binding(
      get: { updateCoordinator.automaticallyDownloadsUpdates },
      set: { updateCoordinator.automaticallyDownloadsUpdates = $0 }
    )
  }
}

private struct SettingsToggleRow: View {
  let icon: String
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      Label(title, systemImage: icon)
    }
  }
}
