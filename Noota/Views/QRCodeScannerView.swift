// Noota/Views/QRCodeScannerView.swift
import SwiftUI
import AVFoundation // للوصول إلى الكاميرا ومسح QR Code

// بروتوكول لتمرير النتيجة من الماسح الضوئي
protocol QRCodeScannerDelegate: AnyObject {
    func didScanQRCode(result: String)
    func scannerDidFail(error: Error)
    func scannerDidCancel()
}

// UIViewControllerRepresentable لجلب AVCaptureSession إلى SwiftUI
struct QRCodeScannerView: UIViewControllerRepresentable {
    // يجب أن يكون الـ delegate ضعيفًا لتجنب دورات الاحتفاظ
    weak var delegate: QRCodeScannerDelegate?

    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.delegate = delegate
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // لا يوجد تحديث هنا حالياً
    }

    // منسق لربط SwiftUI بـ UIKit Delegates
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: QRCodeScannerView

        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
    }
}

// UIViewController الذي يستضيف AVCaptureSession
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRCodeScannerDelegate?

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        // 1. إعداد مدخل الكاميرا
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.scannerDidFail(error: AppError.customError("Failed to get video capture device."))
            return
        }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.scannerDidFail(error: error)
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            delegate?.scannerDidFail(error: AppError.customError("Could not add video input to capture session."))
            return
        }
        captureSession.addInput(videoInput)

        // 2. إعداد مخرج البيانات الوصفية (metadata)
        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            delegate?.scannerDidFail(error: AppError.customError("Could not add metadata output to capture session."))
            return
        }
        captureSession.addOutput(metadataOutput)

        // تحديد أنواع الكائنات التي نريد مسحها (QR Code)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        // 3. إعداد طبقة العرض المسبق (preview layer)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // بدء جلسة الالتقاط
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // دالة الديليجيت التي يتم استدعاؤها عند اكتشاف كود QR
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning() // إيقاف الماسح الضوئي بعد أول مسح ناجح

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate)) // اهتزاز عند المسح
            delegate?.didScanQRCode(result: stringValue) // إرسال النتيجة عبر الديليجيت
        }
    }

    // للتعامل مع التدوير
    override var prefersStatusBarHidden: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
}
