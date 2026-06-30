import Foundation
import OSLog

enum QMarkPerformanceLog {
    static let logger = Logger(subsystem: "com.qmark.app", category: "performance")
    static let pointsOfInterest = OSLog(subsystem: "com.qmark.app", category: .pointsOfInterest)
}
