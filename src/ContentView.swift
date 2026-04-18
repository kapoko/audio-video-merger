import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = DropViewModel()

    var body: some View {
        VStack {
            if viewModel.isProcessing {
                VStack(spacing: 14) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)

                    Text(viewModel.progressLabel())
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            } else {
                dropZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .frame(minWidth: 500, minHeight: 400)
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
