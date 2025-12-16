// Noota/Views/MainAppViewCoordinator.swift
import Foundation
import Combine // بما أننا نستخدم Publishers في FirestoreService

class MainAppViewCoordinator: NSObject, QRCodeScannerDelegate {
    // 💡 بدلاً من مرجع إلى الـ View، نستخدم closures لإبلاغ الـ View بالأحداث
    var didScanQRCodeAction: ((String) -> Void)?
    var scannerDidFailAction: ((Error) -> Void)?
    var scannerDidCancelAction: (() -> Void)?

    init(didScanQRCode: @escaping (String) -> Void,
         scannerDidFail: @escaping (Error) -> Void,
         scannerDidCancel: @escaping () -> Void) {
        self.didScanQRCodeAction = didScanQRCode
        self.scannerDidFailAction = scannerDidFail
        self.scannerDidCancelAction = scannerDidCancel
    }

    func didScanQRCode(result: String) {
        Logger.log("QR Code scanned: \(result)", level: .info)
        // 💡 استدعاء الـ closure لإبلاغ الـ View بالنتيجة
        didScanQRCodeAction?(result)
    }

    func scannerDidFail(error: Error) {
        Logger.log("QR Scanner failed: \(error.localizedDescription)", level: .error)
        // 💡 استدعاء الـ closure لإبلاغ الـ View بالخطأ
        scannerDidFailAction?(error)
    }

    func scannerDidCancel() {
        Logger.log("QR Scanner cancelled.", level: .info)
        // 💡 استدعاء الـ closure لإبلاغ الـ View بالإلغاء
        scannerDidCancelAction?()
    }
}
