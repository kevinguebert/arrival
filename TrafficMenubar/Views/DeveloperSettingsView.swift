import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject var viewModel: CommuteViewModel
    @ObservedObject var mockProvider: MockTrafficProvider
    @ObservedObject var designOverrides: DevDesignOverrides

    @State private var forcedState: ForcedAppState = .normal
    @State private var forcedDirection: CommuteDirection = .toWork
    @State private var forcedFailures: Int = 0

    enum ForcedAppState: String, CaseIterable {
        case normal = "Normal"
        case loading = "Loading"
        case error = "Error"
        case empty = "Empty"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                masterToggle
                if viewModel.isDevMode {
                    appStateSection
                    routeDataSection
                    incidentsSection
                    designOverridesSection
                    quickPresetsSection
                }
            }
            .padding(20)
        }
        .frame(width: 400)
        .frame(minHeight: 500)
        .onChange(of: forcedState) { _ in applyState() }
        .onChange(of: forcedDirection) { _ in applyState() }
        .onChange(of: forcedFailures) { _ in applyState() }
        .onChange(of: mockProvider.travelTimeMinutes) { _ in applyState() }
        .onChange(of: mockProvider.normalTimeMinutes) { _ in applyState() }
        .onChange(of: mockProvider.includeIncidents) { _ in applyState() }
        .onChange(of: mockProvider.incidentCount) { _ in applyState() }
        .onChange(of: mockProvider.maxSeverity) { _ in applyState() }
    }

    // MARK: - Master Toggle

    @ViewBuilder
    private var masterToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text(viewModel.isDevMode ? "Dev Mode Active" : "Dev Mode Off")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                if viewModel.isDevMode {
                    Text("Polling paused · Mock data in use")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.isDevMode },
                set: { enabled in
                    if enabled {
                        viewModel.enableDevMode(mockProvider: mockProvider)
                        applyState()
                    } else {
                        viewModel.disableDevMode()
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(.orange)
        }
        .padding(12)
        .background(viewModel.isDevMode ? Color.orange.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.isDevMode ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - App State

    @ViewBuilder
    private var appStateSection: some View {
        devSection("App State") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Force state")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $forcedState) {
                        ForEach(ForcedAppState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                HStack {
                    Text("Direction")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $forcedDirection) {
                        Text("To Work").tag(CommuteDirection.toWork)
                        Text("To Home").tag(CommuteDirection.toHome)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                HStack {
                    Text("Consecutive failures")
                        .font(.system(size: 12))
                    Spacer()
                    Stepper("\(forcedFailures)", value: $forcedFailures, in: 0...10)
                        .frame(width: 100)
                }
            }
        }
    }

    // MARK: - Route Data

    @ViewBuilder
    private var routeDataSection: some View {
        devSection("Route Data") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Travel time")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(mockProvider.travelTimeMinutes)) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $mockProvider.travelTimeMinutes, in: 1...120, step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Normal time (baseline)")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(mockProvider.normalTimeMinutes)) min")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $mockProvider.normalTimeMinutes, in: 1...120, step: 1)
                }

                let delay = max(0, Int(mockProvider.travelTimeMinutes - mockProvider.normalTimeMinutes))
                let computedMood = TrafficMood(delayMinutes: delay, hasIncidents: mockProvider.includeIncidents)
                HStack {
                    Text("Delay: +\(delay) min")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(computedMood.randomPhrase())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Incidents

    @ViewBuilder
    private var incidentsSection: some View {
        devSection("Incidents") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Include incidents", isOn: $mockProvider.includeIncidents)
                    .font(.system(size: 12))

                if mockProvider.includeIncidents {
                    HStack {
                        Text("Number of incidents")
                            .font(.system(size: 12))
                        Spacer()
                        Stepper("\(mockProvider.incidentCount)", value: $mockProvider.incidentCount, in: 1...3)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Max severity")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $mockProvider.maxSeverity) {
                            Text("Minor").tag(IncidentSeverity.minor)
                            Text("Major").tag(IncidentSeverity.major)
                            Text("Severe").tag(IncidentSeverity.severe)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
            }
        }
    }

    // MARK: - Design Overrides

    @ViewBuilder
    private var designOverridesSection: some View {
        devSection("Design Overrides") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Force mood")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { designOverrides.moodOverride },
                        set: { designOverrides.moodOverride = $0 }
                    )) {
                        Text("Auto").tag(TrafficMood?.none)
                        Text("Clear").tag(TrafficMood?.some(.clear))
                        Text("Moderate").tag(TrafficMood?.some(.moderate))
                        Text("Heavy").tag(TrafficMood?.some(.heavy))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Font scale")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.1f×", designOverrides.fontScale))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $designOverrides.fontScale, in: 0.5...2.0, step: 0.1)
                }
            }
        }
    }

    // MARK: - Quick Presets

    @ViewBuilder
    private var quickPresetsSection: some View {
        devSection("Quick Presets") {
            let presets: [(String, () -> Void)] = [
                ("☀️ Clear roads", {
                    mockProvider.travelTimeMinutes = 25
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = false
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("🌤 Moderate", {
                    mockProvider.travelTimeMinutes = 35
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = false
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("🌧 Heavy + incidents", {
                    mockProvider.travelTimeMinutes = 55
                    mockProvider.normalTimeMinutes = 25
                    mockProvider.includeIncidents = true
                    mockProvider.incidentCount = 2
                    mockProvider.maxSeverity = .severe
                    forcedState = .normal
                    forcedFailures = 0
                }),
                ("💤 Empty state", {
                    forcedState = .empty
                    forcedFailures = 0
                }),
                ("⚡ Loading", {
                    forcedState = .loading
                    forcedFailures = 0
                }),
                ("☁️ Offline", {
                    forcedState = .error
                    forcedFailures = 3
                }),
            ]

            FlowLayout(spacing: 6) {
                ForEach(presets, id: \.0) { label, action in
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func devSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.0)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func applyState() {
        guard viewModel.isDevMode else { return }

        switch forcedState {
        case .normal:
            let result = mockProvider.buildRoutes()
            viewModel.updateFromMock(
                result: result,
                direction: forcedDirection,
                consecutiveFailures: forcedFailures,
                isLoading: false
            )
        case .loading:
            viewModel.updateFromMock(
                result: nil,
                direction: forcedDirection,
                consecutiveFailures: 0,
                isLoading: true
            )
        case .error:
            viewModel.updateFromMock(
                result: nil,
                direction: forcedDirection,
                consecutiveFailures: max(3, forcedFailures),
                isLoading: false
            )
        case .empty:
            viewModel.updateFromMock(
                result: nil,
                direction: forcedDirection,
                consecutiveFailures: 0,
                isLoading: false
            )
        }
    }
}

// MARK: - FlowLayout

/// Simple wrapping layout for preset buttons.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
