import Foundation
import AppKit
import Combine

final class PollScheduler: ObservableObject {
    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let settings: SettingsStore
    private let onPoll: () async -> Void

    @Published var isPaused = false

    init(settings: SettingsStore, onPoll: @escaping () async -> Void) {
        self.settings = settings
        self.onPoll = onPoll
        observeSystemState()
    }

    func start() {
        stop()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.isPaused else {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
                await self.onPoll()
                let interval = self.settings.currentPollingInterval
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollNow() {
        Task {
            await onPoll()
        }
    }

    private func observeSystemState() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                self?.isPaused = true
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.isPaused = false
                self?.pollNow()
            }
            .store(in: &cancellables)
    }

    deinit {
        stop()
    }
}
