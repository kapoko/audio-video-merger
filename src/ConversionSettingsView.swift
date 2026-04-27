import SwiftUI

struct ConversionSettingsView: View {
  @AppStorage(AppSettings.Keys.preferHigherQualityAudio)
  private var preferHigherQualityAudio = false
  @State private var showsPolicyDetails = false

  var body: some View {
    Form {
      Section {
        Toggle(isOn: $preferHigherQualityAudio) {
          HStack(spacing: 6) {
            Label("Prefer higher quality audio", systemImage: "music.note")

            Button {
              showsPolicyDetails = true
            } label: {
              Image(systemName: "questionmark.circle")
                .imageScale(.medium)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Learn more about this setting")
          }
        }

        Text(
          "Based on the output container we try to pass higher quality audio settings to FFmpeg."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .sheet(isPresented: $showsPolicyDetails) {
      ConversionAudioPolicyDetailsView()
    }
  }
}

private struct ConversionAudioPolicyDetailsView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Prefer higher quality audio")
        .font(.title3.weight(.semibold))

      Text("When ")
        + Text("off").bold()
        + Text(": FFmpeg will use sensible container defaults. When ")
        + Text("on").bold()
        + Text(
          ": based on the output container we try to pass higher quality audio settings to FFmpeg."
        )

      Text("Mappings")
        .font(.headline)
        .padding(.top, 4)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(AppSettings.highQualityAudioPolicy) { rule in
            HStack(spacing: 4) {
              Text("\(rule.containersLabel)")
              Text(rule.flagsLabel)  // styled as code pill
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .textSelection(.enabled)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.secondary.opacity(0.08))
    )
    .padding(16)
    .safeAreaInset(edge: .bottom) {
      HStack {
        Spacer()
        Button("Close") {
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(NSColor.windowBackgroundColor))
    }
    .frame(minWidth: 560, minHeight: 460)
  }
}
