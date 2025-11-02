//
//  Logging.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 10/21/25.
//

import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let queue = DispatchQueue(label: "AppLogger.queue")
    private let dateFormatter: DateFormatter
    private let logFileURL: URL

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documents.appendingPathComponent("app_debug.log")
    }

    func log(_ category: String, _ message: String) {
        let ts = dateFormatter.string(from: Date())
        let line = "[\(ts)] [\(category)] \(message)\n"
        // Always print to console as well
        print(line)

        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: self.logFileURL)
            }
        }
    }

    func logAsync(_ category: String, _ message: String) async {
        await withCheckedContinuation { continuation in
            queue.async {
                let ts = self.dateFormatter.string(from: Date())
                let line = "[\(ts)] [\(category)] \(message)\n"
                print(line)
                if let data = line.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                        if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            try? handle.close()
                        }
                    } else {
                        try? data.write(to: self.logFileURL)
                    }
                }
                continuation.resume()
            }
        }
    }
}
