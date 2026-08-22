import Foundation
import Combine

final class MetricProviderRegistry {
    private(set) var providers: [MetricProvider]

    init(providers: [MetricProvider] = []) {
        self.providers = providers
    }

    var ids: [String] { providers.map(\.id) }

    func register(_ provider: MetricProvider) {
        providers.removeAll { $0.id == provider.id }
        providers.append(provider)
    }

    func update(settings: AppSettings) {
        providers.forEach { $0.update(settings: settings) }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var snapshots: [String: MetricSnapshot] = [:]
    @Published private(set) var cycleMetricID: String? = nil
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?

    var providerIDs: [String] { registry.ids }
    var statusMetricIDs: [String] { registry.ids + [StatusMetricID.cycle.rawValue] }

    private let settingsStore: SettingsStore
    private let registry: MetricProviderRegistry
    private var refreshTasks: [String: Task<Void, Never>] = [:]

    init(settingsStore: SettingsStore = SettingsStore(), registry: MetricProviderRegistry? = nil) {
        self.settingsStore = settingsStore
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings
        self.registry = registry ?? MetricProviderRegistry(providers: [
            CodexProvider(),
            LightsailProvider(settings: loadedSettings),
            YuhaiinProvider(settings: loadedSettings),
        ])
    }

    deinit { refreshTasks.values.forEach { $0.cancel() } }

    var selectedMetric: StatusMetricID {
        settings.selectedMetric
    }

    var activeMetricID: String {
        guard selectedMetric == .cycle else { return selectedMetric.rawValue }
        return cycleMetricID ?? availableMetricIDs.first ?? StatusMetricID.codex.rawValue
    }

    var selectedSnapshot: MetricSnapshot? {
        snapshots[activeMetricID]
    }

    func refreshInterval(for providerID: String) -> TimeInterval {
        switch providerID {
        case StatusMetricID.codex.rawValue: return settings.codexRefreshInterval
        case StatusMetricID.lightsail.rawValue: return settings.lightsailRefreshInterval
        case StatusMetricID.yuhaiin.rawValue: return settings.yuhaiinRefreshInterval
        default: return 60
        }
    }

    func applySettings(_ newSettings: AppSettings) {
        var normalized = newSettings
        normalized.codexRefreshInterval = max(30, min(normalized.codexRefreshInterval, 86_400))
        normalized.lightsailRefreshInterval = max(60, min(normalized.lightsailRefreshInterval, 86_400))
        normalized.yuhaiinRefreshInterval = max(1, min(normalized.yuhaiinRefreshInterval, 3_600))
        normalized.cycleDisplayInterval = max(2, min(normalized.cycleDisplayInterval, 60))
        normalized.yuhaiinURL = normalized.yuhaiinURL.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.awsRegion = normalized.awsRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        settings = normalized
        if normalized.selectedMetric != .cycle { cycleMetricID = nil }
        settingsStore.save(normalized)
        registry.update(settings: normalized)
        refreshAll()
    }

    func refreshAll() {
        registry.ids.forEach(refresh)
    }

    func refresh(_ providerID: String) {
        guard refreshTasks[providerID] == nil,
              let provider = registry.providers.first(where: { $0.id == providerID }) else { return }

        isRefreshing = true
        let language = settings.language
        refreshTasks[providerID] = Task { [weak self] in
            let snapshot: MetricSnapshot
            do {
                snapshot = try await provider.load(language: language)
            } catch {
                snapshot = Self.failureSnapshot(for: provider.id, error: error, language: language)
            }

            guard !Task.isCancelled else { return }
            self?.snapshots[provider.id] = snapshot
            self?.reconcileCycle()
            self?.lastRefresh = Date()
            self?.refreshTasks[provider.id] = nil
            self?.isRefreshing = !(self?.refreshTasks.isEmpty ?? true)
        }
    }

    func snapshot(for id: String) -> MetricSnapshot? { snapshots[id] }

    func advanceCycle() {
        guard selectedMetric == .cycle else { return }
        let available = availableMetricIDs
        guard !available.isEmpty else {
            cycleMetricID = nil
            return
        }
        guard let current = cycleMetricID, let index = available.firstIndex(of: current) else {
            cycleMetricID = available[0]
            return
        }
        cycleMetricID = available[(index + 1) % available.count]
    }

    private var availableMetricIDs: [String] {
        registry.ids.filter { snapshots[$0]?.state == .ready }
    }

    private func reconcileCycle() {
        guard selectedMetric == .cycle else { return }
        if !availableMetricIDs.contains(cycleMetricID ?? "") {
            cycleMetricID = availableMetricIDs.first
        }
    }

    nonisolated private static func failureSnapshot(for id: String, error: Error, language: AppLanguage) -> MetricSnapshot {
        let isNotConfigured: Bool
        if let providerError = error as? ProviderError {
            if case .notConfigured = providerError { isNotConfigured = true } else { isNotConfigured = false }
        } else {
            isNotConfigured = false
        }
        let configured = !isNotConfigured
        let state: MetricState = configured ? .failed : .unavailable
        return MetricSnapshot(
            id: id,
            value: "—",
            subtitle: L10n.text(configured ? .error : .unavailable, language),
            rows: [MetricRow(label: L10n.text(.status, language), value: error.localizedDescription)],
            detailSections: [MetricDetailSection(id: "status", title: L10n.text(.status, language), rows: [MetricRow(label: L10n.text(.status, language), value: error.localizedDescription)])],
            detailStyle: .standard,
            accent: configured ? .warning : .neutral,
            state: state,
            progress: nil,
            updatedAt: nil,
            errorMessage: error.localizedDescription
        )
    }
}
