import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject private var viewModel = DropViewModel.shared

  private var flameGradient: LinearGradient {
    LinearGradient(
      colors: [
        Color(red: 0.984, green: 0.773, blue: 0.047),
        Color(red: 0.745, green: 0.239, blue: 0.086),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  var body: some View {
    VStack {
      if viewModel.isProcessing {
        VStack(spacing: 14) {
          CircularProgressRing(progress: viewModel.progress)
            .padding(.bottom, 12)

          if let symbolName = viewModel.progressSymbolName() {
            HStack(spacing: 8) {
              Image(systemName: symbolName)
                .foregroundColor(.green)

              Text(viewModel.progressLabel())
                .foregroundColor(.primary)

              if let jobLabel = viewModel.jobProgressLabel() {
                Text(jobLabel)
                  .font(.system(size: 11, weight: .semibold, design: .rounded))
                  .foregroundColor(.secondary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(
                    Capsule(style: .continuous)
                      .fill(Color.secondary.opacity(0.15))
                  )
              }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .multilineTextAlignment(.center)
          } else {
            HStack(spacing: 8) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .controlSize(.small)

              Text(viewModel.progressLabel())
                .foregroundColor(.primary)

              if let jobLabel = viewModel.jobProgressLabel() {
                Text(jobLabel)
                  .font(.system(size: 11, weight: .semibold, design: .rounded))
                  .foregroundColor(.secondary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(
                    Capsule(style: .continuous)
                      .fill(Color.secondary.opacity(0.15))
                  )
              }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .multilineTextAlignment(.center)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
      } else {
        dropZone
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(16)
    .alert(isPresented: $viewModel.showUnrecognizedFilesAlert) {
      Alert(
        title: Text("Unsupported Files"),
        message: Text(viewModel.unrecognizedFilesMessage),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private var dropZone: some View {
    VStack {
      if let symbolName = viewModel.statusSymbolName() {
        HStack(spacing: 8) {
          Image(systemName: symbolName)
            .foregroundColor(.clear)
            .overlay(
              flameGradient.mask(
                Image(systemName: symbolName)
              )
            )

          Text(viewModel.statusText())
            .foregroundColor(.primary)
        }
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .multilineTextAlignment(.center)
      } else {
        Text(viewModel.statusText())
          .font(.system(size: 16, weight: .medium, design: .rounded))
          .foregroundColor(.primary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(16)
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          viewModel.isDragHovering ? Color.orange : Color.accentColor,
          style: StrokeStyle(lineWidth: 2, dash: [8, 6])
        )
    )
    .animation(.easeInOut(duration: 0.2), value: viewModel.isDragHovering)
    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $viewModel.isDragHovering) { providers in
      viewModel.handleDrop(providers: providers)
    }
  }
}

private struct CircularProgressRing: View {
  let progress: Double

  private var clampedProgress: Double {
    min(max(progress, 0), 1)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)

      Circle()
        .trim(from: 0, to: clampedProgress)
        .stroke(
          Color.accentColor,
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeOut(duration: 0.3), value: clampedProgress)

      Text("\(Int(clampedProgress * 100))%")
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundColor(.primary)
    }
    .frame(width: 128, height: 128)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Progress"))
    .accessibilityValue(Text("\(Int(clampedProgress * 100)) percent"))
  }
}
