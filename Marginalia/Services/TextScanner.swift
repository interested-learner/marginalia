import SwiftUI
import VisionKit

/// VisionKit's scanner in text mode: point at the page, tap the passage.
///
/// The same controller `BarcodeScanner` points at the back cover, told to
/// recognize text instead of an EAN-13. **Tapping is the whole interaction** —
/// everything in frame highlights, and only what the reader touches is kept, so
/// a facing page or a running head never arrives uninvited.
///
/// **The simulator has no camera**, so `isAvailable` is false there and the
/// screen says so in words rather than presenting a black rectangle. Camera
/// permission is asked for by the controller at first use, never at launch.
struct TextScanner: UIViewControllerRepresentable {
    /// One tapped item's text, as recognized. Joining is `ScannedPassage`'s job.
    let onTap: (String) -> Void
    let onProblem: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    /// Every iPhone has a camera, so this is the simulator and a Mac. It still
    /// says what to do instead, because a dead end is never the answer here —
    /// the same rule that keeps manual entry beside the barcode.
    static let unavailable = "no camera here — type the passage in as a quote instead"

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // `recognizesMultipleItems` is what puts every line of the page in
        // reach at once; with one item the reader would be aiming rather than
        // choosing. High frame rate tracking is for a moving subject and a
        // page held in two hands isn't one.
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onTap = onTap
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            onProblem("the camera didn't start — allow it in settings, or type the passage")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    /// A line arrives when it's tapped and never on its own.
    ///
    /// The same line tapped twice is dropped: `RecognizedItem` keeps its id
    /// while it stays in frame, and a thumb that lands twice on one line means
    /// one line — not the same sentence in the passage twice.
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onTap: (String) -> Void
        private var taken: Set<RecognizedItem.ID> = []

        init(onTap: @escaping (String) -> Void) {
            self.onTap = onTap
        }

        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case .text(let text) = item, taken.insert(item.id).inserted else { return }
            onTap(text.transcript)
        }
    }
}

/// The scanner, full screen, with the app's own chrome over it — there is no
/// system navigation bar anywhere in this app and the camera doesn't get one.
///
/// The passage builds at the foot as it's tapped, because a reader pointing a
/// phone at a book needs to see what they've collected before they lower it.
struct TextScannerScreen: View {
    let onDone: (String) -> Void
    let onCancel: () -> Void

    @State private var passage = ""
    @State private var problem: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            if TextScanner.isAvailable {
                TextScanner(
                    onTap: { line in
                        passage = ScannedPassage.appending(line, to: passage)
                    },
                    onProblem: { problem = $0 }
                )
                .ignoresSafeArea()
            } else {
                Theme.canvas.ignoresSafeArea()
                EmptyState(message: TextScanner.unavailable)
                    .frame(maxHeight: .infinity, alignment: .center)
            }

            VStack(spacing: 0) {
                Hairline()

                if let problem {
                    CaptureProblem(message: problem)
                }

                // What's been tapped so far, in the quote rule it will wear as
                // a note — and in a **fixed** box, like the capture sheet's
                // recording panel. The buttons stay where the thumb left them
                // as lines are added, which matters more here than anywhere
                // else in the app: this is the one screen operated while
                // holding a book open with the other hand. Long passages
                // scroll inside it rather than pushing anything off.
                if !passage.isEmpty {
                    ScrollView {
                        QuoteRule(text: passage)
                            .padding(.horizontal, 20)
                    }
                    .frame(height: 150)
                    .scrollBounceBehavior(.basedOnSize)
                    .padding(.top, 8)
                } else if TextScanner.isAvailable {
                    Text("tap each line of the passage")
                        .font(Typography.source)
                        .foregroundStyle(Theme.textMute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 150)
                        .padding(.horizontal, 20)
                }
                // With no camera the message above has already said everything
                // there is to say, and a second line under it would be the
                // screen explaining itself twice.

                // Disabled until something has been tapped, because that's the
                // shape of the flow — but gone entirely where there's no
                // camera, since nothing on that machine could ever enable it.
                if TextScanner.isAvailable || !passage.isEmpty {
                    MarkerButton(title: "\(Glyphs.add) use it", enabled: !passage.isEmpty) {
                        onDone(passage)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                MarkerButton(title: "\(Glyphs.close) cancel", kind: .secondary, action: onCancel)
                    .padding(.horizontal, 20)
                    .padding(.top, TextScanner.isAvailable || !passage.isEmpty ? 8 : 16)
                    .padding(.bottom, 32)
            }
            .background(Theme.canvas)
        }
        .background(Theme.canvas)
        .task { passageAtLaunch() }
    }

    /// `-scanned "<text>"` fills the passage without a camera, which is the
    /// only way to see this screen with something in it on a simulator.
    private func passageAtLaunch() {
        guard let text = UserDefaults.standard.string(forKey: "scanned"), !text.isEmpty
        else { return }
        passage = ScannedPassage.appending(text, to: passage)
    }
}
