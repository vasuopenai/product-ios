/// The camera with barcode detection (UPC-A/E, EAN-13/8) via AVFoundation. On iPhones with
/// several back cameras it uses the virtual device, which switches to the ultra-wide for close
/// focus, so barcodes held near the lens stay sharp.

import AVFoundation
import SwiftUI

struct BarcodeScanner: UIViewRepresentable {
    var running: Bool
    var torch: Bool
    var onCode: (String) -> Void

    func makeUIView(context: Context) -> ScannerView {
        let view = ScannerView()
        view.configure()
        return view
    }

    func updateUIView(_ view: ScannerView, context: Context) {
        view.onCode = onCode
        view.setRunning(running)
        view.setTorch(running && torch)
    }

    static func dismantleUIView(_ view: ScannerView, coordinator: ()) {
        view.setTorch(false)
        view.setRunning(false)
    }
}

final class ScannerView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "foodgenie.scanner")
    private var device: AVCaptureDevice?
    private var wantRunning = false
    private var wantTorch = false
    private var configured = false

    func configure() {
        guard !configured else { return }
        configured = true
        backgroundColor = .black
        preview.session = session
        preview.videoGravity = .resizeAspectFill

        let output = AVCaptureMetadataOutput()
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back)
        guard let device = discovery.devices.first else { return }
        self.device = device

        queue.async { [session] in
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input),
                  session.canAddOutput(output) else { return }
            session.addInput(input)
            session.addOutput(output)
            let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce]
            output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
            if (try? device.lockForConfiguration()) != nil {
                if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
                device.unlockForConfiguration()
            }
        }
        output.setMetadataObjectsDelegate(self, queue: .main)
    }

    func setRunning(_ on: Bool) {
        guard on != wantRunning else { return }
        wantRunning = on
        queue.async { [session] in
            if on, !session.isRunning { session.startRunning() }
            if !on, session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        guard on != wantTorch, let device, device.hasTorch else { return }
        wantTorch = on
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let code = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first,
              !code.isEmpty else { return }
        onCode?(code)
    }
}
