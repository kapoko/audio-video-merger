import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject private var viewModel = DropViewModel.shared

  var body: some View {
    VStack {
      if viewModel.isProcessing {
        VStack(spacing: 14) {
          CircularProgressRing(progress: viewModel.progress)
            .padding(.bottom, 12)

          Text(viewModel.progressLabel())
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
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
      Text(viewModel.statusText())
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)
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
