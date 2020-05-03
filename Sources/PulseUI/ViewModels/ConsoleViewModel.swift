// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    private let logger: Logger
    private let container: NSPersistentContainer
    private var controller: NSFetchedResultsController<MessageEntity>

    @Published private(set) var messages: ConsoleMessages

    @Published var searchText: String = ""
    @Published var searchCriteria: ConsoleSearchCriteria = .init()
    @Published var onlyErrors: Bool = false

    init(logger: Logger) {
        self.logger = logger
        self.container = logger.container

        let request = NSFetchRequest<MessageEntity>(entityName: "\(MessageEntity.self)")
        request.fetchBatchSize = 40
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.createdAt, ascending: false)]

        self.controller = NSFetchedResultsController<MessageEntity>(fetchRequest: request, managedObjectContext: container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        self.messages = ConsoleMessages(messages: self.controller.fetchedObjects ?? [])

        super.init()

        controller.delegate = self
        try? controller.performFetch()

        Publishers.CombineLatest($searchText, $searchCriteria).sink { [unowned self] searchText, criteria in
            self.refresh(searchText: searchText, criteria: criteria)
        }.store(in: &bag)

        $onlyErrors.sink { [unowned self] in
            self.setOnlyErrorsEnabled($0)
        }.store(in: &bag)
    }

    private func refresh(searchText: String, criteria: ConsoleSearchCriteria) {
        update(request: controller.fetchRequest, searchText: searchText, criteria: criteria, logger: logger)
        try? controller.performFetch()
        self.messages = ConsoleMessages(messages: self.controller.fetchedObjects ?? [])
    }

    private func setOnlyErrorsEnabled(_ onlyErrors: Bool) {
        var filters = searchCriteria.filters
        filters.removeAll(where: { $0.kind == .level })
        if onlyErrors {
            filters.append(ConsoleSearchFilter(text: "error", kind: .level, relation: .equals))
            filters.append(ConsoleSearchFilter(text: "fatal", kind: .level, relation: .equals))
        }
        searchCriteria.filters = filters
    }

    func prepareForSharing() throws -> URL {
        try ConsoleShareService(logger: logger).prepareForSharing()
    }

    func buttonRemoveAllMessagesTapped() {
        try? logger.store.removeAllMessages()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.messages = ConsoleMessages(messages: self.controller.fetchedObjects ?? [])
    }
}
