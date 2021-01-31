// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).
// Licensed under Apache License v2.0 with Runtime Library Exception.

import Foundation
import Pulse
import CoreData
import Logging

#if DEBUG
public extension LoggerMessageStore {
    static let mock: LoggerMessageStore = {
        let store = makeMockStore()
        populateStore(store)

        //        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        //            logger.log("Hello, world")
        //        }

        return store
    }()
}

private func makeMockStore() -> LoggerMessageStore {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("com.github.kean.pulse-ui-demo")
    try? FileManager.default.removeItem(at: rootURL)
    try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)

    let storeURL = rootURL.appendingPathComponent("demo-store")
    return LoggerMessageStore(storeURL: storeURL)
}

private extension NSManagedObject {
    convenience init(using usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }
}

private func populateStore(_ store: LoggerMessageStore) {
    precondition(Thread.isMainThread)

    func logger(named: String) -> Logger {
        var logger = Logger(label: named, factory: { PersistentLogHandler(label: $0, store: store) })
        logger.logLevel = .trace
        return logger
    }

    logger(named: "application")
        .log(level: .info, "UIApplication.didFinishLaunching")

    logger(named: "application")
        .log(level: .info, "UIApplication.willEnterForeground")

    logger(named: "auth")
        .log(level: .trace, "Instantiated Session")

    logger(named: "auth")
        .log(level: .trace, "Instantiated the new login request")

    let networkLogger = NetworkLogger(logger(named: "network"))

    let urlSession = URLSession(configuration: .default)
    let dataTask = urlSession.dataTask(with: MockDataTask.login.request)

    networkLogger.urlSession(urlSession, didStartTask: dataTask)
    Thread.sleep(forTimeInterval: 0.01)
    networkLogger.urlSession(urlSession, dataTask: dataTask, didReceive: MockDataTask.login.response)
    Thread.sleep(forTimeInterval: 0.01)
    networkLogger.urlSession(urlSession, dataTask: dataTask, didReceive: MockDataTask.login.responseBody)
//    networkLogger.testInjectMetrics(<#T##metrics: NetworkLoggerMetrics##NetworkLoggerMetrics#>, for: <#T##URLSessionTask#>)
    networkLogger.urlSession(urlSession, task: dataTask, didCompleteWithError: nil)

    logger(named: "application")
        .log(level: .info, "Will navigate to Dashboard")

    let stackTrace = """
        Replace this implementation with code to handle the error appropriately. fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

        2015-12-08 15:04:03.888 Conversion[76776:4410388] call stack:
        (
            0   Conversion                          0x000694b5 -[ViewController viewDidLoad] + 128
            1   UIKit                               0x27259f55 <redacted> + 1028
            ...
            9   UIKit                               0x274f67a7 <redacted> + 134
            10  FrontBoardServices                  0x2b358ca5 <redacted> + 232
            11  FrontBoardServices                  0x2b358f91 <redacted> + 44
            12  CoreFoundation                      0x230e87c7 <redacted> + 14
            ...
            16  CoreFoundation                      0x23038ecd CFRunLoopRunInMode + 108
            17  UIKit                               0x272c7607 <redacted> + 526
            18  UIKit                               0x272c22dd UIApplicationMain + 144
            19  Conversion                          0x000767b5 main + 108
            20  libdyld.dylib                       0x34f34873 <redacted> + 2
        )
        """

    logger(named: "auth")
        .log(level: .debug, .init(stringLiteral: stackTrace))

    logger(named: "default")
        .log(level: .critical, "💥 0xDEADBEEF")

    // Wait until everything is stored
    store.container.viewContext.performAndWait {}
}
#endif
