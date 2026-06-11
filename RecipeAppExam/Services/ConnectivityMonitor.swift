// Services/ConnectivityMonitor.swift

import Network
import Combine

// MARK: - ConnectivityMonitor

/// Wraps NWPathMonitor to publish internet-reachability changes on the main thread.
/// Injected as a dependency so unit tests can supply a stub that controls
/// the published value without spinning up real network probes.
final class ConnectivityMonitor: ObservableObject {

    @Published private(set) var isConnected: Bool = true

    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue

    // MARK: - Init / Deinit

    init() {
        monitor = NWPathMonitor()
        monitorQueue = DispatchQueue(label: "com.recipeapp.connectivity", qos: .utility)
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }
}
