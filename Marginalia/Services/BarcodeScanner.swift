import SwiftUI
import VisionKit

/// VisionKit's scanner in barcode mode, reading the EAN-13 off the back of a
/// book. The same controller phase 9 points at a printed page for text.
///
/// **The simulator has no camera**, so `isAvailable` is false there and the
/// form says so in words rather than presenting a black rectangle. Camera
/// permission is asked for by the controller at first use, never at launch.
struct BarcodeScanner: UIViewControllerRepresentable {
    /// A normalized isbn. Payloads that aren't books never reach here.
    let onFound: (String) -> Void
    let onProblem: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    static let unavailable = "no camera here — type the isbn instead"

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            onProblem("the camera didn't start — allow it in settings, or type the isbn")
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    /// Fires once. A barcode stays in frame for several seconds after it's
    /// read, and handing the same isbn back a dozen times would restart the
    /// lookup under the reader's thumb.
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onFound: (String) -> Void
        private var reported = false

        init(onFound: @escaping (String) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didAdd added: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !reported else { return }
            for item in added {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      let isbn = ISBN.normalized(payload)
                else { continue }

                reported = true
                onFound(isbn)
                return
            }
        }
    }
}

/// The scanner, full screen, with the app's own chrome over it — there is no
/// system navigation bar anywhere in this app and the camera doesn't get one.
struct BarcodeScannerScreen: View {
    let onFound: (String) -> Void
    let onCancel: () -> Void

    @State private var problem: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            if BarcodeScanner.isAvailable {
                BarcodeScanner(onFound: onFound) { problem = $0 }
                    .ignoresSafeArea()
            } else {
                Theme.canvas.ignoresSafeArea()
                EmptyState(message: BarcodeScanner.unavailable)
                    .frame(maxHeight: .infinity, alignment: .center)
            }

            VStack(spacing: 0) {
                Hairline()
                if let problem {
                    CaptureProblem(message: problem)
                }
                Text("point at the barcode on the back cover")
                    .font(Typography.source)
                    .foregroundStyle(Theme.textMute)
                    .padding(.top, 16)

                MarkerButton(title: "\(Glyphs.close) cancel", kind: .secondary, action: onCancel)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
            .background(Theme.canvas)
        }
        .background(Theme.canvas)
    }
}
