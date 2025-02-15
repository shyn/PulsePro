// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(watchOS) || os(iOS)

import CoreData
import Combine
import PulseCore
import WatchConnectivity
import SwiftUI

@available(iOS 13, watchOS 6, *)
final class LoggerSyncSession: ObservableObject {
    @Published fileprivate(set) var fileTransferStatus: FileTransferStatus = .initial

    private let delegate: SessionDelegate
    fileprivate var directory: TemporaryDirectory?

    static let shared = LoggerSyncSession()

    init() {
        self.delegate = SessionDelegate()
        self.delegate.session = self

        if WCSession.isSupported() {
            WCSession.default.delegate = delegate
            WCSession.default.activate()
        }
    }

    func transfer(store: LoggerStore) {
        let directory = TemporaryDirectory()
        let date = ShareItems.makeCurrentDate()
        let storeURL = directory.url.appendingPathComponent("logs-\(date).pulse", isDirectory: true)
        _ = try? store.copy(to: storeURL)

        let session = WCSession.default.transferFile(storeURL, metadata: nil)
        self.fileTransferStatus = .sending(session.progress)
        self.directory = directory
    }
}

@available(iOS 13, watchOS 6, *)
private final class SessionDelegate: NSObject, WCSessionDelegate {
    unowned var session: LoggerSyncSession!

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        debugPrint("WCSession did activate")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        debugPrint("WCSession did deactivate")
    }
    #endif

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            debugPrint("Failed to active watch communication session: \(error)")
        }
    }

    #if os(iOS)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            do {
                let directory = TemporaryDirectory()
                let storeURL = directory.url.appendingPathComponent(file.fileURL.lastPathComponent, isDirectory: false)
                try FileManager.default.moveItem(at: file.fileURL, to: storeURL)

                runHapticFeedback(.success)
                ToastView {
                    HStack {
                        Image(systemName: "applewatch.watchface")
                        Text("Store received")
                        Spacer().frame(width: 16)
                        Button("Open", action: {
                            let store = try? LoggerStore(storeURL: storeURL)
                            let vc = UIViewController.present { dismiss in
                                MainView(store: store ?? .empty, onDismiss: dismiss)
                            }
                            vc?.onDeinit(directory.remove)
                        }).foregroundColor(Color.blue)
                    }
                }.show()
            } catch {
                runHapticFeedback(.error)
            }
        }
    }
    #endif

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            self.session.directory?.remove()
            if let error = error {
                self.session.fileTransferStatus = .failure(error)
            } else {
                self.session.fileTransferStatus = .success
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.session.fileTransferStatus = .initial
            }
        }
    }
}

@available(iOS 13, watchOS 6, *)
enum FileTransferStatus {
    case initial
    case sending(Progress)
    case failure(Error)
    case success

    var title: String {
        switch self {
        case .initial:
            return "Send to iPhone"
        case .failure:
            return "Transfer Failed"
        case .sending:
            return "Sending..."
        case .success:
            return "Store Sent"
        }
    }

    var isButtonDisabled: Bool {
        switch self {
        case .initial:
            return false
        default:
            return true
        }
    }
}

struct FileTransferError: Identifiable {
    let id = UUID()
    let message: String
}
#endif
