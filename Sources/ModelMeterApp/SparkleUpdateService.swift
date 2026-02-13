import AppKit
import Combine
import Sparkle

// MARK: - Types

enum SparkleUpdateState: Equatable {
    case idle
    case checking
    case available(version: String)
    case upToDate
    case failed(message: String)
}

@MainActor
protocol SparkleUpdateDriving: AnyObject {
    var statePublisher: AnyPublisher<SparkleUpdateState, Never> { get }
    func start()
    func checkForUpdates()
    var canCheck: Bool { get }
}

// MARK: - SparkleDriver

@MainActor
final class SparkleDriver: NSObject, SparkleUpdateDriving {
    private var updaterController: SPUStandardUpdaterController!
    private let stateSubject = CurrentValueSubject<SparkleUpdateState, Never>(.idle)

    var statePublisher: AnyPublisher<SparkleUpdateState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var canCheck: Bool {
        updaterController.updater.canCheckForUpdates
    }

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func start() {
        do {
            try updaterController.updater.start()
        } catch {
            NSLog("SparkleDriver: Failed to start updater: %@", error.localizedDescription)
        }
        updaterController.updater.automaticallyChecksForUpdates = true
    }

    func checkForUpdates() {
        stateSubject.send(.checking)
        updaterController.updater.checkForUpdates()
    }
}

// MARK: - SPUUpdaterDelegate

extension SparkleDriver: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor in
            self.stateSubject.send(.available(version: version))
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let nsError = error as NSError
        Task { @MainActor in
            if nsError.domain == SUSparkleErrorDomain, nsError.code == 1001 {
                self.stateSubject.send(.upToDate)
            } else {
                self.stateSubject.send(.failed(message: error.localizedDescription))
            }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let nsError = error as NSError
        Task { @MainActor in
            if nsError.domain == SUSparkleErrorDomain, nsError.code == 1001 {
                self.stateSubject.send(.upToDate)
            } else {
                self.stateSubject.send(.failed(message: error.localizedDescription))
            }
        }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        Task { @MainActor in
            guard self.stateSubject.value == .checking else { return }
            if let error {
                let nsError = error as NSError
                if nsError.domain == SUSparkleErrorDomain, nsError.code == 1001 {
                    self.stateSubject.send(.upToDate)
                } else {
                    self.stateSubject.send(.failed(message: error.localizedDescription))
                }
            } else {
                self.stateSubject.send(.upToDate)
            }
        }
    }
}

// MARK: - NoopSparkleDriver

@MainActor
final class NoopSparkleDriver: SparkleUpdateDriving {
    private let stateSubject = CurrentValueSubject<SparkleUpdateState, Never>(.idle)

    var statePublisher: AnyPublisher<SparkleUpdateState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var canCheck: Bool { false }

    func start() {}

    func checkForUpdates() {
        stateSubject.send(.failed(message: "Sparkle updater is not available."))
    }
}
