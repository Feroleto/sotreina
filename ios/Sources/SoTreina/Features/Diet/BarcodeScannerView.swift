import AVFoundation
import os
import SoTreinaDesign
import SoTreinaKit
import SwiftUI
import Vision
import VisionKit

/// The web's `BarcodeScannerPage` on VisionKit's `DataScannerViewController`
/// (product codes only: EAN-13, which also carries UPC-A, EAN-8, UPC-E).
/// Always dark, like a camera. A read code goes to `GET /foods/barcode/:code`:
/// found → `onFound`, 404 → `onNotFound` (manual cadastro linked to the code).
struct BarcodeScannerView: View {
    let onFound: (FoodListItem) -> Void
    let onNotFound: (String) -> Void
    @State private var status: Status = .starting
    @State private var detected = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SessionStore.self) private var session

    private static let log = Logger(subsystem: "com.feroleto.sotreina", category: "diet")

    enum Status: Equatable {
        case starting
        case scanning
        case lookingUp
        case lookupError
        case cameraError
        case cameraDenied
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("diet.scanner.cancel", bundle: .l10n)
                        .font(Font.geist(13, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 8)

            GeometryReader { geo in
                let frame = Self.frame(in: geo.size)
                ZStack {
                    if status == .scanning {
                        // same space as the frame: regionOfInterest is in the scanner's own view
                        DataScanner(regionOfInterest: frame) { code in found(code) }
                        CornerFrame(rect: frame)
                    } else {
                        message
                            .padding(.horizontal, 32)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .clipped()

            if status == .scanning {
                Text("diet.scanner.instructions", bundle: .l10n)
                    .font(Font.geist(13, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.success, trigger: detected)
        .task { await start() }
    }

    /// The web's box: 90% of the width up to 420 pt, 200 pt tall (≤ 60%).
    private static func frame(in size: CGSize) -> CGRect {
        let width = min(size.width * 0.9, 420)
        let height = min(200, size.height * 0.6)
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    @ViewBuilder private var message: some View {
        switch status {
        case .starting, .scanning:
            EmptyView()
        case .lookingUp:
            Text("diet.scanner.lookingUp", bundle: .l10n)
                .font(Font.geist(13, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
        case .lookupError, .cameraError, .cameraDenied:
            VStack(spacing: 12) {
                Text(errorKey, bundle: .l10n)
                    .font(Font.geist(13, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                if status == .cameraDenied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text("diet.scanner.openSettings", bundle: .l10n)
                    }
                    .buttonStyle(.chip)
                } else if status == .lookupError {
                    Button { status = .scanning } label: {
                        Text("diet.scanner.retry", bundle: .l10n)
                    }
                    .buttonStyle(.chip)
                }
            }
        }
    }

    private var errorKey: LocalizedStringKey {
        switch status {
        case .lookupError: "diet.scanner.lookupError"
        case .cameraDenied: "diet.scanner.cameraDenied"
        default: "diet.scanner.cameraError"
        }
    }

    // MARK: Camera

    /// `isAvailable` is false until the camera permission is granted, so ask first.
    private func start() async {
        guard DataScannerViewController.isSupported else {
            status = .cameraError
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                status = .cameraDenied
                return
            }
        default:
            status = .cameraDenied
            return
        }
        status = DataScannerViewController.isAvailable ? .scanning : .cameraError
    }

    // MARK: Lookup

    private func found(_ code: String) {
        guard status == .scanning else { return }
        detected += 1
        status = .lookingUp
        Task {
            do {
                guard let food: FoodListItem = try await session.api.get("foods/barcode/\(code)") else {
                    throw APIError.invalidResponse
                }
                onFound(food)
            } catch APIError.http(status: 404) {
                onNotFound(code)
            } catch {
                if case APIError.unauthorized = error {
                    session.expire()
                    return
                }
                Self.log.error("barcode lookup failed: \(String(describing: error), privacy: .public)")
                status = .lookupError
            }
        }
    }
}

/// L-shaped mustard corners, a center line, and the dimmed surround — one
/// element, like the web's `CornerFrame`, so the dimming can't drift from it.
private struct CornerFrame: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let dim = Color.black.opacity(0.48)
                let size = geo.size
                // four bands around the box: top, bottom, left, right
                dim.frame(width: size.width, height: rect.minY).position(x: size.width / 2, y: rect.minY / 2)
                dim.frame(width: size.width, height: size.height - rect.maxY)
                    .position(x: size.width / 2, y: (rect.maxY + size.height) / 2)
                dim.frame(width: rect.minX, height: rect.height).position(x: rect.minX / 2, y: rect.midY)
                dim.frame(width: size.width - rect.maxX, height: rect.height)
                    .position(x: (rect.maxX + size.width) / 2, y: rect.midY)
            }
            Corners()
                .stroke(Color.acc, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            Rectangle()
                .fill(Color.acc)
                .frame(width: rect.width, height: 2)
                .position(x: rect.midX, y: rect.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Corners: Shape {
        func path(in rect: CGRect) -> Path {
            let arm: CGFloat = 28
            let radius: CGFloat = 6
            var path = Path()
            for (corner, dx, dy) in [
                (CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0),
            ] {
                path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
                path.addArc(
                    tangent1End: corner, tangent2End: CGPoint(x: corner.x + dx * arm, y: corner.y), radius: radius
                )
                path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
            }
            return path
        }
    }
}

/// `DataScannerViewController` for one product code at a time. It reads only
/// inside `regionOfInterest` (the frame drawn over it), draws no highlights of
/// its own, and drops codes whose check digit fails (a misread digit).
private struct DataScanner: UIViewControllerRepresentable {
    let regionOfInterest: CGRect
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if scanner.regionOfInterest != regionOfInterest { scanner.regionOfInterest = regionOfInterest }
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let code = barcode.payloadStringValue,
                      let kind = Self.kind(barcode.observation.symbology),
                      ProductBarcode.isValid(code, kind: kind)
                else { continue }
                dataScanner.stopScanning()
                onCode(code)
                return
            }
        }

        private static func kind(_ symbology: VNBarcodeSymbology) -> ProductBarcode.Kind? {
            switch symbology {
            case .ean13: .ean13
            case .ean8: .ean8
            case .upce: .upcE
            default: nil
            }
        }
    }
}
