// Noota/Views/QRCodeScannerView.swift
import SwiftUI
import AVFoundation // للوصول إلى الكاميرا ومسح QR Code
import AudioToolbox // For SystemSoundID(kSystemSoundID_Vibrate)

// بروتوكول لتمرير النتيجة من الماسح الضوئي
// 🚨 هذا هو التعديل المطلوب 🚨
protocol QRCodeScannerDelegate: AnyObject { // تم إضافة : AnyObject
    func didScanQRCode(result: String)
    func scannerDidFail(error: Error)
    func scannerDidCancel()
}

// UIViewControllerRepresentable لجلب AVCaptureSession إلى SwiftUI
struct QRCodeScannerView: UIViewControllerRepresentable {
    // يجب أن يكون الـ delegate ضعيفًا لتجنب دورات الاحتفاظ
    weak var delegate: QRCodeScannerDelegate? // هذا السطر سيصبح صحيحًا بعد التعديل أعلاه

    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.delegate = delegate
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // لا يوجد تحديث هنا حالياً
    }
}

struct QRCodeScannerContainerView: View {
    weak var delegate: (any QRCodeScannerDelegate)?

    var body: some View {
        ZStack {
            // ✅ استخدام QRCodeScannerView هنا لأنها UIViewControllerRepresentable
            QRCodeScannerView(delegate: delegate)
                .edgesIgnoringSafeArea(.all)
            
            // ✅ طبقة الإطار والنص
            QRCodeOverlayView()
        }
    }
}

// UIViewController الذي يستضيف AVCaptureSession
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRCodeScannerDelegate? // هذا السطر سيصبح صحيحًا أيضًا

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    // تعريف AppError كـ Error
    enum AppError: Error, LocalizedError {
        case customError(String)
        var errorDescription: String? {
            switch self {
            case .customError(let message):
                return message
            }
        }
    }

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
    // دالة الديليجيت التي يتم استدعاؤها عند اكتشاف كود QR
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            // ✅ الخطوة 1: التحقق من وجود كود QR صالح
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }

                // ✅ الخطوة 2: إيقاف جلسة الكاميرا فورًا بعد المسح الأول
                self.captureSession.stopRunning()
                
                // ✅ الخطوة 3: تشغيل الاهتزاز مرة واحدة فقط
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // ✅ الخطوة 4: إرسال النتيجة عبر الـ delegate
                delegate?.didScanQRCode(result: stringValue)
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

struct QRCodeOverlayView: View {
    var body: some View {
        ZStack {
            // ✅ إطار مربع بسيط
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 250, height: 250)
            
            // ✅ النص التوجيهي
            Text("Align QR Code Here To Scan")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .offset(y: 180)
        }
    }
}
