import Foundation

enum LogLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
}

struct Logger {
    // لا نحتاج إلى دالة setup() في هذا الكلاس البسيط
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("[\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)")
                #endif
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        print("[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line) \(function)] \(message)")
    }
}
