import SwiftUI

extension MetricAccent {
    var color: Color {
        switch self {
        case .indigo: return Color(red: 0.42, green: 0.39, blue: 1.0)
        case .amber: return Color(red: 1.0, green: 0.62, blue: 0.20)
        case .cyan: return Color(red: 0.13, green: 0.78, blue: 0.86)
        case .neutral: return .secondary
        case .warning: return .orange
        }
    }
}

/// Corner radii shared by every surface so the panel reads as one system.
enum Radius {
    static let panel: CGFloat = 22
    static let hero: CGFloat = 20
    static let card: CGFloat = 16
    static let control: CGFloat = 10
}

enum Motion {
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static let navigation = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let panel = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let value = Animation.spring(response: 0.5, dampingFraction: 0.86)
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.7)
    static let hover = Animation.easeOut(duration: 0.16)

    /// Animation for data arriving from providers; nil when Reduce Motion is on.
    static var update: Animation? { reduceMotion ? nil : value }
}

// MARK: - Root

struct MainView: View {
    @ObservedObject var store: AppStore
    let onQuit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var detailID: String?

    var body: some View {
        ZStack {
            if store.isPanelVisible {
                ZStack {
                    BackgroundView()
                    content
                }
                .transition(.asymmetric(
                    insertion: reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity),
                    removal: .identity
                ))
            }
        }
        .frame(width: 480, height: 680)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : Motion.panel, value: store.isPanelVisible)
    }

    @ViewBuilder
    private var content: some View {
        if showingSettings {
            SettingsView(store: store) { navigate { showingSettings = false } }
                .transition(pushTransition)
        } else if let detailID {
            DetailView(store: store, providerID: detailID) { navigate { self.detailID = nil } }
                .transition(pushTransition)
        } else {
            DashboardView(
                store: store,
                openSettings: { navigate { showingSettings = true } },
                openDetails: { id in navigate { detailID = id } },
                onQuit: onQuit
            )
            .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
        }
    }

    private var pushTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private func navigate(_ change: () -> Void) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : Motion.navigation, change)
    }
}

struct BackgroundView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.indigo.opacity(0.10)).frame(width: 260).blur(radius: 50).offset(x: 180, y: -280)
            Circle().fill(Color.cyan.opacity(0.07)).frame(width: 220).blur(radius: 60).offset(x: -180, y: 300)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var store: AppStore
    let openSettings: () -> Void
    let openDetails: (String) -> Void
    let onQuit: () -> Void

    private var language: AppLanguage { store.settings.language }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    Text(L10n.text(.liveSignals, language).uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    signalGrid
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
            RefreshFooter(
                isRefreshing: store.isRefreshing,
                statusText: "\(L10n.text(.updated, language)) \(Fmt.clock(store.lastRefresh))",
                language: language,
                action: store.refreshAll
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Color.primary.opacity(0.09))
                Image(systemName: "waveform.path.ecg").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(.appName, language)).font(.system(size: 16, weight: .bold, design: .rounded))
                Text(L10n.text(.overview, language)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: openSettings) { Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .semibold)) }
                .buttonStyle(GlassIconButtonStyle())
                .help(L10n.text(.settings, language))
            Button(action: onQuit) { Image(systemName: "power").font(.system(size: 13, weight: .semibold)) }
                .buttonStyle(GlassIconButtonStyle())
                .help(L10n.text(.close, language))
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var hero: some View {
        let id = store.activeMetricID
        let snapshot = store.selectedSnapshot
        let color = snapshot?.accent.color ?? MetricAccent.indigo.color
        let history = store.rateHistory[id] ?? []
        return Button { openDetails(id) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.providerName(id, language)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(snapshot?.value ?? "—")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                        Text(snapshot?.subtitle ?? L10n.text(.waiting, language)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    StatusOrb(state: snapshot?.state ?? .loading, color: color, pulseKey: snapshot?.updatedAt)
                }

                if let snapshot {
                    if let progress = snapshot.progress {
                        ProgressBar(value: progress, color: color)
                    } else if history.count >= 2 {
                        Sparkline(samples: history, color: color).frame(height: 40)
                    }
                    HStack(spacing: 12) {
                        ForEach(snapshot.rows.prefix(3)) { row in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                Text(row.value).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                                    .contentTransition(.numericText())
                            }
                            if row.id != snapshot.rows.prefix(3).last?.id { Spacer(minLength: 4) }
                        }
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heroBackground(color: color))
        }
        .buttonStyle(CardButtonStyle(radius: Radius.hero))
    }

    /// Rows of two; an odd last card spans the full width instead of leaving a hole.
    private var signalGrid: some View {
        let ids = store.providerIDs
        let rows = stride(from: 0, to: ids.count, by: 2).map { Array(ids[$0..<min($0 + 2, ids.count)]) }
        return VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row, id: \.self) { id in
                        SignalCard(
                            id: id,
                            snapshot: store.snapshot(for: id),
                            history: store.rateHistory[id] ?? [],
                            language: language,
                            isSelected: id == store.activeMetricID,
                            wide: row.count == 1,
                            openDetails: openDetails
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heroBackground(color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [color.opacity(0.16), Color.primary.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RadialGradient(colors: [color.opacity(0.20), .clear], center: .topTrailing, startRadius: 0, endRadius: 240)
                    .clipShape(shape)
            )
            .overlay(shape.stroke(color.opacity(0.22), lineWidth: 1))
    }
}

struct SignalCard: View {
    let id: String
    let snapshot: MetricSnapshot?
    let history: [LiveRate]
    let language: AppLanguage
    let isSelected: Bool
    let wide: Bool
    let openDetails: (String) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return Button { openDetails(id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                    Text(L10n.providerName(id, language)).font(.caption.weight(.semibold)).lineLimit(1)
                    if isSelected {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(color)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                }
                if wide && hasHistory {
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            valueText
                            subtitleText
                        }
                        .layoutPriority(1)
                        Sparkline(samples: history, color: color).frame(height: 46)
                    }
                } else {
                    valueText
                    subtitleText.frame(minHeight: wide ? nil : 30, alignment: .topLeading)
                    Spacer(minLength: 0)
                    indicator
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(shape.fill(Color.primary.opacity(0.045)))
            .overlay(shape.stroke(isSelected ? color.opacity(0.30) : Color.primary.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(CardButtonStyle(radius: Radius.card))
    }

    private var hasHistory: Bool { history.count >= 2 }

    private var valueText: some View {
        Text(snapshot?.value ?? "—")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }

    private var subtitleText: some View {
        Text(snapshot?.subtitle ?? L10n.text(.waiting, language))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    @ViewBuilder
    private var indicator: some View {
        if snapshot?.progress == nil, hasHistory {
            Sparkline(samples: history, color: color).frame(height: 24)
        } else {
            ProgressBar(value: snapshot?.progress, color: color)
        }
    }

    private var icon: String {
        switch id {
        case StatusMetricID.codex.rawValue: return "sparkles"
        case StatusMetricID.lightsail.rawValue: return "cloud.fill"
        default: return "arrow.up.arrow.down"
        }
    }

    private var color: Color { snapshot?.accent.color ?? (id == StatusMetricID.codex.rawValue ? MetricAccent.indigo.color : .secondary) }
}

// MARK: - Indicators

struct ProgressBar: View {
    let value: Double?
    let color: Color
    var height: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let fraction = CGFloat(max(0, min(100, value ?? 0)) / 100)
            // No sliver at 0%; otherwise never thinner than the bar is tall.
            let width = fraction > 0 ? max(height, proxy.size.width * fraction) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(value == nil ? 0.05 : 0.08))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: appeared ? width : 0)
                    .shadow(color: color.opacity(0.35), radius: 3)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : Motion.value, value: value)
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(Motion.value.delay(0.06)) { appeared = true } }
        }
    }
}

/// Download (filled) and upload (dashed) rate history, newest sample on the right.
struct Sparkline: View {
    let samples: [LiveRate]
    let color: Color
    var showsUpload = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Offset in sample steps; set to 1 when a new sample arrives, then animated back to 0 so the line slides left.
    @State private var shift: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let capacity = AppStore.historyCapacity
            let step = proxy.size.width / CGFloat(max(capacity - 1, 1))
            let peak = max(samples.map { max($0.download, $0.upload) }.max() ?? 0, 1)
            let downloads = samples.map(\.download)
            ZStack {
                SparkShape(values: downloads, peak: peak, capacity: capacity, closed: true)
                    .fill(LinearGradient(colors: [color.opacity(0.30), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                SparkShape(values: downloads, peak: peak, capacity: capacity, closed: false)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                if showsUpload {
                    SparkShape(values: samples.map(\.upload), peak: peak, capacity: capacity, closed: false)
                        .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round, dash: [2.5, 2.5]))
                }
            }
            .offset(x: shift * step)
        }
        .clipped()
        .onChange(of: samples.last?.at) { _ in
            guard !reduceMotion else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { shift = 1 }
            withAnimation(.easeOut(duration: 0.6)) { shift = 0 }
        }
    }
}

struct SparkShape: Shape {
    let values: [Double]
    let peak: Double
    let capacity: Int
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        let step = rect.width / CGFloat(max(capacity - 1, 1))
        let startX = rect.maxX - step * CGFloat(values.count - 1)
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: startX + step * CGFloat(index),
                y: rect.maxY - 1 - (rect.height - 2) * CGFloat(min(max(value / peak, 0), 1))
            )
        }
        path.move(to: points[0])
        for index in 1..<points.count {
            let previous = points[index - 1]
            let mid = CGPoint(x: (previous.x + points[index].x) / 2, y: (previous.y + points[index].y) / 2)
            path.addQuadCurve(to: mid, control: previous)
        }
        path.addLine(to: points[points.count - 1])
        if closed {
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct StatusOrb: View {
    let state: MetricState
    let color: Color
    var size: CGFloat = 60
    /// A change (typically `updatedAt`) emits a soft ripple to show fresh data.
    var pulseKey: Date? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleScale: CGFloat = 0.7
    @State private var rippleOpacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.6), lineWidth: 1.5)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            Circle().fill(color.opacity(0.10))
            Circle().fill(color.opacity(0.18)).padding(size * 0.15)
            if state == .loading {
                SpinnerArc(color: color).padding(size * 0.15 - 1)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.27, weight: .bold))
                .foregroundStyle(color)
                .id(symbol)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: symbol)
        .onChange(of: pulseKey) { _ in ripple() }
    }

    private var symbol: String {
        switch state {
        case .ready: return "checkmark"
        case .loading: return "ellipsis"
        case .failed: return "exclamationmark"
        case .unavailable: return "minus"
        }
    }

    private func ripple() {
        guard !reduceMotion, state == .ready else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            rippleScale = 0.72
            rippleOpacity = 0.9
        }
        withAnimation(.easeOut(duration: 1.0)) {
            rippleScale = 1.1
            rippleOpacity = 0
        }
    }
}

struct SpinnerArc: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spinning = true }
            }
    }
}

struct SpinningSymbol: View {
    let name: String
    let spinning: Bool

    var body: some View {
        if spinning {
            SpinningImage(name: name)
        } else {
            Image(systemName: name)
        }
    }
}

private struct SpinningImage: View {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        Image(systemName: name)
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { angle = 360 }
            }
    }
}

struct StatusDot: View {
    let active: Bool

    var body: some View {
        ZStack {
            if active { PulseRing(color: .orange) }
            Circle().fill(active ? Color.orange : Color.green).frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
    }
}

private struct PulseRing: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.5))
            .frame(width: 7, height: 7)
            .scaleEffect(expanded ? 2.2 : 1)
            .opacity(expanded ? 0 : 0.8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { expanded = true }
            }
    }
}

/// Footer shared by the dashboard and detail views. Refresh state is debounced so
/// sub-second polls (e.g. Yuhaiin every few seconds) don't make the footer flicker.
struct RefreshFooter: View {
    let isRefreshing: Bool
    let statusText: String
    let language: AppLanguage
    let action: () -> Void

    @State private var busy = false

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(active: busy)
            Text(busy ? L10n.text(.waiting, language) : statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            Spacer()
            Button(action: action) {
                HStack(spacing: 5) {
                    SpinningSymbol(name: "arrow.clockwise", spinning: busy)
                    Text(L10n.text(.refresh, language))
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.035))
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1) }
        .animation(.easeInOut(duration: 0.2), value: busy)
        .task(id: isRefreshing) {
            guard isRefreshing else {
                busy = false
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { busy = true }
        }
    }
}

// MARK: - Detail

struct DetailView: View {
    @ObservedObject var store: AppStore
    let providerID: String
    let onClose: () -> Void

    private var language: AppLanguage { store.settings.language }
    private var snapshot: MetricSnapshot? { store.snapshot(for: providerID) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(GlassIconButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.providerName(providerID, language))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(L10n.text(.details, language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let snapshot {
                    StatusOrb(state: snapshot.state, color: snapshot.accent.color, size: 36, pulseKey: snapshot.updatedAt)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let snapshot {
                        if snapshot.detailStyle == .codexQuota {
                            codexDetail(snapshot)
                        } else {
                            detailHero(snapshot)
                            ForEach(snapshot.detailSections) { section in
                                detailSection(section, color: snapshot.accent.color)
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(L10n.text(.waiting, language)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            RefreshFooter(
                isRefreshing: store.isRefreshing,
                statusText: snapshot.map { "\(L10n.text(.updated, language)) \(Fmt.clock($0.updatedAt))" } ?? L10n.text(.waiting, language),
                language: language,
                action: { store.refresh(providerID) }
            )
        }
    }

    private func detailHero(_ snapshot: MetricSnapshot) -> some View {
        let color = snapshot.accent.color
        let history = store.rateHistory[providerID] ?? []
        let shape = RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Spacer()
                Text(snapshot.state == .ready ? L10n.text(.ready, language) : snapshot.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
            }
            Text(snapshot.subtitle).font(.caption).foregroundStyle(.secondary)
            if snapshot.progress == nil, history.count >= 2 {
                Sparkline(samples: history, color: color).frame(height: 96)
                HStack(spacing: 14) {
                    legend(L10n.text(.download, language), color: color, dashed: false)
                    legend(L10n.text(.upload, language), color: Color.primary.opacity(0.45), dashed: true)
                    Spacer()
                }
            } else if snapshot.progress != nil {
                ProgressBar(value: snapshot.progress, color: color)
            }
        }
        .padding(16)
        .background(shape.fill(color.opacity(0.10)))
        .overlay(shape.stroke(color.opacity(0.18), lineWidth: 1))
    }

    private func legend(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: 12, y: 1))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashed ? [2.5, 2.5] : []))
            .frame(width: 12, height: 2)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func codexDetail(_ snapshot: MetricSnapshot) -> some View {
        if let quota = snapshot.detailSections.first(where: { $0.id == "quota" }) {
            codexQuotaCard(snapshot, section: quota)
        }
        HStack(alignment: .top, spacing: 12) {
            if let credits = snapshot.detailSections.first(where: { $0.id == "credits" }) {
                codexMiniCard(
                    title: L10n.text(.credits, language),
                    icon: "bolt.fill",
                    mainValue: detailValue(credits, .credits),
                    rows: [
                        (L10n.text(.local, language), detailValue(credits, .local)),
                        (L10n.text(.cloud, language), detailValue(credits, .cloud)),
                    ],
                    color: snapshot.accent.color
                )
            }
            if let resetCredits = snapshot.detailSections.first(where: { $0.id == "resetCredits" }) {
                codexMiniCard(
                    title: L10n.text(.resetCredits, language),
                    icon: "arrow.clockwise.circle.fill",
                    mainValue: detailValue(resetCredits, .available),
                    rows: [
                        (L10n.text(.available, language), detailValue(resetCredits, .available)),
                        (L10n.text(.applicable, language), detailValue(resetCredits, .applicable)),
                    ],
                    color: snapshot.accent.color
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        if let account = snapshot.detailSections.first(where: { $0.id == "account" }) {
            detailSection(account, color: snapshot.accent.color)
        }
    }

    private func codexQuotaCard(_ snapshot: MetricSnapshot, section: MetricDetailSection) -> some View {
        let used = detailValue(section, .used)
        let window = detailValue(section, .primaryWindow)
        let reset = detailValue(section, .reset)
        let resetIn = detailValue(section, .resetIn)
        let secondaryLabel = L10n.text(.secondaryWindow, language)
        let secondaryUsedLabel = "\(secondaryLabel) \(L10n.text(.used, language))"
        let secondaryResetInLabel = "\(secondaryLabel) \(L10n.text(.resetIn, language))"
        let secondaryWindow = section.rows.first(where: { $0.label == secondaryLabel })?.value
        let secondaryUsed = section.rows.first(where: { $0.label == secondaryUsedLabel })?.value
        let secondaryResetIn = section.rows.first(where: { $0.label == secondaryResetInLabel })?.value
        let color = snapshot.accent.color
        let shape = RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text(.remaining, language)).font(.caption).foregroundStyle(.secondary)
                    Text(snapshot.value)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label(window, systemImage: "clock").font(.caption.weight(.medium))
                    Text("\(L10n.text(.used, language)) \(used)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ProgressBar(value: snapshot.progress, color: color)
            Divider().opacity(0.5)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text(.reset, language)).font(.caption2).foregroundStyle(.secondary)
                    Text(reset).font(.caption.weight(.medium))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.text(.resetIn, language)).font(.caption2).foregroundStyle(.secondary)
                    Text(resetIn).font(.caption.weight(.medium))
                }
            }
            if let secondaryWindow, secondaryWindow != "-" {
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(secondaryLabel, systemImage: "calendar")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(secondaryWindow)
                            .font(.caption.weight(.medium))
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text(.used, language)).font(.caption2).foregroundStyle(.secondary)
                            Text(secondaryUsed ?? "—").font(.caption.weight(.medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(L10n.text(.resetIn, language)).font(.caption2).foregroundStyle(.secondary)
                            Text(secondaryResetIn ?? "—").font(.caption.weight(.medium))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(shape.fill(LinearGradient(colors: [color.opacity(0.12), Color.primary.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(shape.stroke(color.opacity(0.18), lineWidth: 1))
    }

    private func codexMiniCard(title: String, icon: String, mainValue: String, rows: [(String, String)], color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(mainValue)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                        Spacer()
                        Text(row.1)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(shape.fill(Color.primary.opacity(0.045)))
        .overlay(shape.stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func detailValue(_ section: MetricDetailSection, _ key: CopyKey) -> String {
        section.rows.first(where: { $0.label == L10n.text(key, language) })?.value ?? "—"
    }

    private func detailSection(_ section: MetricDetailSection, color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(color)
            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.label).foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(row.value)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
                            .textSelection(.enabled)
                            .contentTransition(.numericText())
                    }
                    .font(.caption)
                    .padding(.vertical, 8)
                    if index < section.rows.count - 1 { Divider().opacity(0.35) }
                }
            }
            .padding(.horizontal, 13)
            .background(shape.fill(Color.primary.opacity(0.045)))
            .overlay(shape.stroke(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var store: AppStore
    let onClose: () -> Void
    @State private var draft: AppSettings

    init(store: AppStore, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
        _draft = State(initialValue: store.settings)
    }

    private var language: AppLanguage { draft.language }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Image(systemName: "chevron.left") }.buttonStyle(GlassIconButtonStyle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(.settings, language)).font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(L10n.text(.menuBarDisplay, language)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    generalSection
                    refreshRatesSection
                    yuhaiinSection
                    awsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }

            HStack {
                Button(L10n.text(.cancel, language), action: onClose).buttonStyle(.borderless)
                Spacer()
                Button { store.applySettings(draft); onClose() } label: { Label(L10n.text(.saveAndRefresh, language), systemImage: "checkmark") }
                    .buttonStyle(.borderedProminent)
                    .tint(MetricAccent.indigo.color)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035))
            .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1) }
        }
    }

    private var generalSection: some View {
        SettingsSection(title: L10n.text(.menuBarDisplay, language), icon: "menubar.rectangle") {
            Picker(L10n.text(.language, language), selection: $draft.language) {
                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
            }
            Picker(L10n.text(.chooseStatusMetric, language), selection: $draft.statusMetricID) {
                ForEach(store.statusMetricIDs, id: \.self) { id in Text(L10n.providerName(id, language)).tag(id) }
            }
        }
    }

    private var refreshRatesSection: some View {
        SettingsSection(title: L10n.text(.refreshRates, language), icon: "timer") {
            intervalRow(L10n.text(.codexRefreshRate, language), value: $draft.codexRefreshInterval, placeholder: "300")
            intervalRow(L10n.text(.lightsailRefreshRate, language), value: $draft.lightsailRefreshInterval, placeholder: "600")
            intervalRow(L10n.text(.yuhaiinRefreshRate, language), value: $draft.yuhaiinRefreshInterval, placeholder: "5")
            intervalRow(L10n.text(.cycleDisplayRate, language), value: $draft.cycleDisplayInterval, placeholder: "8")
            Text(L10n.text(.refreshHint, language)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func intervalRow(_ title: String, value: Binding<Double>, placeholder: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Text(L10n.text(.seconds, language)).foregroundStyle(.secondary)
        }
    }

    private var yuhaiinSection: some View {
        SettingsSection(title: L10n.text(.yuhaiin, language), icon: "arrow.up.arrow.down") {
            TextField(L10n.text(.yuhaiinURL, language), text: $draft.yuhaiinURL)
                .textFieldStyle(.roundedBorder)
            SecureField(L10n.text(.yuhaiinToken, language), text: $draft.yuhaiinToken)
                .textFieldStyle(.roundedBorder)
            Text(L10n.text(.yuhaiinHint, language)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var awsSection: some View {
        SettingsSection(title: L10n.text(.awsSettings, language), icon: "cloud.fill") {
            SecureField(L10n.text(.awsAccessKey, language), text: $draft.awsAccessKey).textFieldStyle(.roundedBorder)
            SecureField(L10n.text(.awsSecretKey, language), text: $draft.awsSecretKey).textFieldStyle(.roundedBorder)
            SecureField(L10n.text(.awsSessionToken, language), text: $draft.awsSessionToken).textFieldStyle(.roundedBorder)
            HStack {
                TextField(L10n.text(.awsRegion, language), text: $draft.awsRegion).textFieldStyle(.roundedBorder)
                TextField(L10n.text(.awsProfile, language), text: $draft.awsProfile).textFieldStyle(.roundedBorder)
            }
            Text(L10n.text(.awsHTTPHint, language)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(L10n.text(.credentialsOptional, language)).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .background(shape.fill(Color.primary.opacity(0.045)))
        .overlay(shape.stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Button styles

/// Clickable card: highlight + slight lift on hover, gentle squeeze on press.
struct CardButtonStyle: ButtonStyle {
    var radius: CGFloat = Radius.card

    func makeBody(configuration: Configuration) -> some View {
        CardButtonBody(configuration: configuration, radius: radius)
    }
}

private struct CardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let radius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .overlay(shape.fill(Color.primary.opacity(configuration.isPressed ? 0.06 : (hovering ? 0.03 : 0))).allowsHitTesting(false))
            .overlay(shape.stroke(Color.primary.opacity(hovering ? 0.10 : 0), lineWidth: 1).allowsHitTesting(false))
            .contentShape(shape)
            .shadow(color: .black.opacity(hovering ? 0.10 : 0), radius: hovering ? 10 : 0, y: hovering ? 4 : 0)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.985 : 1)
            .offset(y: !reduceMotion && hovering && !configuration.isPressed ? -1 : 0)
            .onHover { hovering = $0 }
            .animation(Motion.press, value: configuration.isPressed)
            .animation(Motion.hover, value: hovering)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassIconButtonBody(configuration: configuration)
    }
}

private struct GlassIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : (hovering ? 0.11 : 0.07)))
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .onHover { hovering = $0 }
            .animation(Motion.press, value: configuration.isPressed)
            .animation(Motion.hover, value: hovering)
    }
}
