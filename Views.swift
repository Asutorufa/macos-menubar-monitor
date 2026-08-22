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

struct MainView: View {
    @ObservedObject var store: AppStore
    let onQuit: () -> Void

    @State private var showingSettings = false
    @State private var detailID: String?

    var body: some View {
        ZStack {
            BackgroundView()
            if showingSettings {
                SettingsView(store: store) { showingSettings = false }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let detailID {
                DetailView(store: store, providerID: detailID) { self.detailID = nil }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                DashboardView(store: store, openSettings: { withAnimation(.easeInOut(duration: 0.22)) { showingSettings = true } }, openDetails: { id in withAnimation(.easeInOut(duration: 0.22)) { detailID = id } }, onQuit: onQuit)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 480, height: 680)
        .animation(.easeInOut(duration: 0.22), value: showingSettings)
        .animation(.easeInOut(duration: 0.22), value: detailID)
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
                .padding(.bottom, 16)
            }
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.09))
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
        return VStack(alignment: .leading, spacing: 14) {
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
                StatusOrb(state: snapshot?.state ?? .loading, color: snapshot?.accent.color ?? .secondary)
            }

            if let snapshot {
                ProgressBar(value: snapshot.progress, color: snapshot.accent.color)
                HStack(spacing: 12) {
                    ForEach(snapshot.rows.prefix(3)) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Text(row.value).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        if row.id != snapshot.rows.prefix(3).last?.id { Spacer(minLength: 4) }
                    }
                }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(18)
        .background(cardBackground(color: snapshot?.accent.color ?? .indigo, prominent: true))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { openDetails(id) }
    }

    private var signalGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.providerIDs, id: \.self) { id in
                SignalCard(id: id, snapshot: store.snapshot(for: id), language: language, isSelected: id == store.activeMetricID, openDetails: openDetails)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(store.isRefreshing ? Color.orange : Color.green).frame(width: 7, height: 7)
            Text(store.isRefreshing ? L10n.text(.waiting, language) : "\(L10n.text(.updated, language)) \(Fmt.clock(store.lastRefresh))")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(action: store.refreshAll) {
                if store.isRefreshing { ProgressView().controlSize(.small) }
                else { Label(L10n.text(.refresh, language), systemImage: "arrow.clockwise") }
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.035))
    }

    private func cardBackground(color: Color, prominent: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: prominent ? 22 : 18, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(prominent ? 0.16 : 0.09), Color.primary.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: prominent ? 22 : 18, style: .continuous).stroke(color.opacity(prominent ? 0.22 : 0.10), lineWidth: 1))
    }
}

struct SignalCard: View {
    let id: String
    let snapshot: MetricSnapshot?
    let language: AppLanguage
    let isSelected: Bool
    let openDetails: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                Text(L10n.providerName(id, language)).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                if isSelected { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(color) }
            }
            Text(snapshot?.value ?? "—")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(snapshot?.subtitle ?? L10n.text(.waiting, language))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(minHeight: 30, alignment: .topLeading)
            ProgressBar(value: snapshot?.progress, color: color)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isSelected ? color.opacity(0.12) : Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? color.opacity(0.28) : Color.primary.opacity(0.06), lineWidth: 1))
        .animation(.easeOut(duration: 0.22), value: snapshot?.value)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { openDetails(id) }
    }

    private var icon: String {
        switch id {
        case StatusMetricID.codex.rawValue: return "sparkles"
        case StatusMetricID.lightsail.rawValue: return "cloud.fill"
        default: return "arrow.up.arrow.down"
        }
    }

    private var color: Color { snapshot?.accent.color ?? (id == StatusMetricID.codex.rawValue ? .indigo : .secondary) }
}

struct ProgressBar: View {
    let value: Double?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                if let value {
                    Capsule().fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(5, proxy.size.width * max(0, min(100, value)) / 100))
                        .animation(.easeOut(duration: 0.45), value: value)
                }
            }
        }
        .frame(height: 6)
    }
}

struct StatusOrb: View {
    let state: MetricState
    let color: Color
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(pulsing ? 0.12 : 0.22)).frame(width: 60, height: 60).scaleEffect(pulsing ? 1.18 : 0.92)
            Circle().fill(color.opacity(0.18)).frame(width: 42, height: 42)
            Image(systemName: state == .ready ? "checkmark" : "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(color)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulsing = true } }
    }
}

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
                    StatusOrb(state: snapshot.state, color: snapshot.accent.color)
                        .scaleEffect(0.58)
                        .frame(width: 42, height: 42)
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

            HStack {
                Text(snapshot.map { "\(L10n.text(.updated, language)) \(Fmt.clock($0.updatedAt))" } ?? L10n.text(.waiting, language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.refresh(providerID)
                } label: {
                    if store.isRefreshing { ProgressView().controlSize(.small) }
                    else { Label(L10n.text(.refresh, language), systemImage: "arrow.clockwise") }
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035))
        }
    }

    private func detailHero(_ snapshot: MetricSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Spacer()
                Text(snapshot.state == .ready ? L10n.text(.ready, language) : snapshot.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(snapshot.accent.color)
            }
            Text(snapshot.subtitle).font(.caption).foregroundStyle(.secondary)
            ProgressBar(value: snapshot.progress, color: snapshot.accent.color)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(snapshot.accent.color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(snapshot.accent.color.opacity(0.18), lineWidth: 1))
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
        if let account = snapshot.detailSections.first(where: { $0.id == "account" }) {
            detailSection(account, color: snapshot.accent.color)
        }
    }

    private func codexQuotaCard(_ snapshot: MetricSnapshot, section: MetricDetailSection) -> some View {
        let used = detailValue(section, .used)
        let window = detailValue(section, .primaryWindow)
        let reset = detailValue(section, .reset)
        let resetIn = detailValue(section, .resetIn)
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
            ProgressBar(value: snapshot.progress, color: snapshot.accent.color)
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
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.055)))
    }

    private func codexMiniCard(title: String, icon: String, mainValue: String, rows: [(String, String)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(mainValue).font(.system(size: 25, weight: .bold, design: .rounded))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.045)))
    }

    private func detailValue(_ section: MetricDetailSection, _ key: CopyKey) -> String {
        section.rows.first(where: { $0.label == L10n.text(key, language) })?.value ?? "—"
    }

    private func detailSection(_ section: MetricDetailSection, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    }
                    .font(.caption)
                    .padding(.vertical, 8)
                    if index < section.rows.count - 1 { Divider().opacity(0.35) }
                }
            }
            .padding(.horizontal, 13)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.045)))
        }
    }
}

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
                    .tint(.indigo)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.035))
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
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(configuration.isPressed ? 0.15 : 0.07)))
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
