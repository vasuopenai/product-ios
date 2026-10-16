import AVFoundation
import SwiftUI
import FoodGenieKit

/// One barcode lookup: known products come back at once; new ones are researched on the
/// server (USDA, Open Food Facts, stores, the web) while we poll.
@MainActor
@Observable
final class ScanModel {
    enum Phase {
        case ready
        case loading(String)
        case result(String, ScanResult)
        case failed(String, String)
    }

    private(set) var phase: Phase = .ready
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private let api: APIClient
    private static let pollEvery: Duration = .milliseconds(2500)
    private static let pollFor: TimeInterval = 90

    init(api: APIClient) {
        self.api = api
    }

    var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    func reset() {
        work?.cancel()
        phase = .ready
    }

    func lookUp(_ code: String, store: StoreModel) {
        guard isReady else { return }
        phase = .loading(code)
        let locationId = store.store?.locationId
        let coordinate = store.coordinate
        work = Task {
            do {
                let result = try await api.scan(code, lat: coordinate?.latitude, lng: coordinate?.longitude,
                                                locationId: locationId)
                guard !Task.isCancelled else { return }
                if result.status == .found { Haptics.success() } else { Haptics.warning() }
                phase = .result(code, result)
                if result.status == .researching { await poll(code, locationId: locationId) }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { phase = .failed(code, error.userMessage) }
            }
        }
    }

    private func poll(_ code: String, locationId: String?) async {
        let started = Date.now
        while Date.now.timeIntervalSince(started) < Self.pollFor {
            do {
                try await Task.sleep(for: Self.pollEvery)
                let result = try await api.scanStatus(code, locationId: locationId)
                if result.status != .researching {
                    phase = .result(code, result)
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                // a dropped poll: try again until the time is up
            }
        }
    }
}

struct ScanView: View {
    @Environment(StoreModel.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = ScanModel(api: AppConfig.api)
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var visible = false
    @State private var torch = false
    @State private var typing = false

    var body: some View {
        ZStack {
            if camera == .authorized {
                cameraLayer
            } else {
                Theme.background.ignoresSafeArea()
                if model.isReady { permissionPrompt }
            }
            VStack {
                Spacer()
                if !model.isReady { resultSheet }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
            .frame(maxWidth: maxContentWidth)
            .animation(.spring(duration: 0.35), value: model.isReady)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { visible = true }
        .onDisappear {
            visible = false
            torch = false
        }
        .sheet(isPresented: $typing) {
            TypeBarcodeSheet { code in
                model.reset()
                model.lookUp(code, store: store)
            }
        }
    }

    // MARK: Camera

    private var cameraLayer: some View {
        ZStack {
            BarcodeScanner(running: visible && scenePhase == .active, torch: torch) { code in
                if model.isReady { model.lookUp(code, store: store) }
            }
            .ignoresSafeArea()

            ViewfinderFrame()
                .frame(width: 270, height: 170)
                .allowsHitTesting(false)
            if model.isReady {
                Text("Point at a barcode")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6)
                    .offset(y: 125)
                    .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    StoreChip(onCamera: true)
                    Spacer()
                    CameraButton(icon: "keyboard", label: "Type a barcode") { typing = true }
                    CameraButton(icon: torch ? "flashlight.on.fill" : "flashlight.off.fill", active: torch,
                                 label: torch ? "Turn off light" : "Turn on light") { torch.toggle() }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                Spacer()
            }
        }
    }

    @ViewBuilder private var permissionPrompt: some View {
        EmptyState(icon: "barcode.viewfinder", title: "Scan barcodes",
                   message: "Allow camera access to scan products in the store. You can also type the barcode.") {
            VStack(spacing: Spacing.s) {
                if camera == .notDetermined {
                    AppButton(label: "Allow camera", icon: "camera") {
                        Task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            camera = AVCaptureDevice.authorizationStatus(for: .video)
                        }
                    }
                } else {
                    AppButton(label: "Turn on camera in Settings", icon: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                AppButton(label: "Type a barcode", icon: "keyboard", kind: .secondary) { typing = true }
            }
        }
        .padding(.horizontal, Spacing.l)
        .onChange(of: scenePhase) {
            camera = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    // MARK: Result

    private var resultSheet: some View {
        VStack(spacing: Spacing.m) {
            ScanResultBody(phase: model.phase)
            AppButton(label: "Scan another", icon: "barcode.viewfinder",
                      kind: { if case .loading = model.phase { return .secondary } else { return .primary } }()) {
                model.reset()
            }
        }
        .padding(Spacing.l)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ScanResultBody: View {
    let phase: ScanModel.Phase

    var body: some View {
        switch phase {
        case .ready:
            EmptyView()
        case .loading(let code):
            StatusRow(icon: "magnifyingglass", title: "Looking up…", message: code, busy: true)
        case .failed(_, let message):
            StatusRow(icon: "exclamationmark.triangle", title: "That didn’t work", message: message)
        case .result(_, let result):
            resultView(result)
        }
    }

    @ViewBuilder private func resultView(_ result: ScanResult) -> some View {
        let draft = result.staged?.draft ?? Draft()
        if result.status == .found, let product = result.product {
            ProductCard(product: product)
        } else if result.status == .researching {
            StatusRow(icon: "globe", title: "New to us — looking it up",
                      message: "Checking USDA, Open Food Facts, stores and the web. This takes a few seconds.", busy: true)
        } else if result.status == .pending, let product = result.staged?.product {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ProductCard(product: product)
                Text("Found online — not reviewed by us yet, so some details may be missing or off.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        } else if result.status == .pending, let name = draft.name {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    ProductImage(url: draft.imageURL, size: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        if let brand = draft.brand {
                            Text(brand.uppercased()).font(.caption2.weight(.semibold)).tracking(0.4)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text(name).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                        if let size = draft.packageSize {
                            Text(size).font(.footnote).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                StatusRow(icon: "clock", title: "Found online — under review",
                          message: "Thanks for scanning! We’ll add it to Food Genie after a quick check, with full nutrition and ingredients.")
            }
        } else {
            StatusRow(icon: "magnifyingglass", title: "We couldn’t find this one yet",
                      message: "Thanks — we’ve noted it and will try to add it soon.")
        }
    }
}

/// Four white corners around the area to aim at.
struct ViewfinderFrame: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, c: CGFloat = 28, r: CGFloat = 14
            Path { p in
                p.move(to: CGPoint(x: 0, y: c))
                p.addLine(to: CGPoint(x: 0, y: r))
                p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
                p.addLine(to: CGPoint(x: c, y: 0))

                p.move(to: CGPoint(x: w - c, y: 0))
                p.addLine(to: CGPoint(x: w - r, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: c))

                p.move(to: CGPoint(x: w, y: h - c))
                p.addLine(to: CGPoint(x: w, y: h - r))
                p.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w - c, y: h))

                p.move(to: CGPoint(x: c, y: h))
                p.addLine(to: CGPoint(x: r, y: h))
                p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: h - c))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

struct CameraButton: View {
    let icon: String
    var active = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? .black : .white)
                .frame(width: 40, height: 40)
                .background {
                    if active {
                        Circle().fill(.white)
                    } else {
                        Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    }
                }
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

struct TypeBarcodeSheet: View {
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Type a barcode").font(.title2.weight(.bold)).foregroundStyle(Theme.text)
            Text("The numbers under the bars, 8 to 14 digits.").font(.subheadline).foregroundStyle(Theme.textSecondary)
            TextField("0 49000 02891 1", text: $code)
                .font(.title2.monospacedDigit().weight(.semibold))
                .tracking(2)
                .keyboardType(.numberPad)
                .focused($focused)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .onChange(of: code) {
                    let digits = String(code.filter(\.isNumber).prefix(14))
                    if digits != code { code = digits }
                }
            AppButton(label: "Look it up", icon: "magnifyingglass", disabled: code.count < 8) {
                onSubmit(code)
                dismiss()
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.xl)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
        .onAppear { focused = true }
    }
}
