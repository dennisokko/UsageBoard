import AppKit
import SwiftUI
import UsageBoardCore

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case plugins = "插件"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .plugins: return "puzzlepiece.extension"
        case .about: return "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "启动、快捷键与显示"
        case .plugins: return "管理 API 用量查询插件"
        case .about: return "应用信息与更新"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject var store: UsageBoardStore
    @State private var selectedTab: SettingsTab = .general
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar

            Divider()

            // Content
            VStack(spacing: 0) {
                // Page header
                pageHeader

                Divider()

                // Content area
                switch selectedTab {
                case .general:
                    ScrollView {
                        GeneralSettingsView(store: store)
                            .padding(20)
                    }
                case .plugins:
                    PluginSettingsView(store: store)
                case .about:
                    ScrollView {
                        AboutView(store: store)
                            .padding(20)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App icon area
            HStack {
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 16)

            Divider()
                .padding(.horizontal, 12)

            // Navigation items
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Spacer()
        }
        .frame(width: 170)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedTab.rawValue)
                .font(.system(size: 20, weight: .semibold))
            Text(selectedTab.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var store: UsageBoardStore

    var body: some View {
        SettingsSection {
            SettingsRow(label: "开机启动") {
                Toggle("", isOn: $store.configuration.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: store.configuration.launchAtLogin) { newValue in
                        store.toggleLaunchAtLogin(newValue)
                        store.saveConfiguration()
                    }
                    .frame(width: 120, alignment: .leading)
            }

            SettingsRow(label: "显示模式") {
                Picker("", selection: $store.configuration.overviewDisplayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(displayModeName(mode)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 120, alignment: .leading)
                .onChange(of: store.configuration.overviewDisplayMode) { _ in
                    store.saveConfiguration()
                }
            }
        }
    }

    private func displayModeName(_ mode: DisplayMode) -> String {
        switch mode {
        case .grouped: return "分组"
        case .tabs: return "标签页"
        }
    }
}

// MARK: - Plugin Settings

struct PluginSettingsView: View {
    @ObservedObject var store: UsageBoardStore
    @State private var selectedPluginID: UUID?
    @State private var draggingPluginID: UUID?
    @State private var draft: PluginConfiguration?

    private var hasChanges: Bool {
        guard let id = selectedPluginID,
              let original = store.configuration.plugins.first(where: { $0.id == id }),
              let draft else { return false }
        return draft.name != original.name
            || draft.executablePath != original.executablePath
            || draft.refreshIntervalSeconds != original.refreshIntervalSeconds
            || draft.parameterValues != original.parameterValues
    }

    var body: some View {
        HStack(spacing: 0) {
            // Plugin list sidebar
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.configuration.plugins) { plugin in
                            pluginListRow(plugin)
                                .tag(plugin.id)
                                .onTapGesture {
                                    loadDraft(for: plugin.id)
                                }
                                .onDrag {
                                    draggingPluginID = plugin.id
                                    return NSItemProvider(object: plugin.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: PluginDropDelegate(
                                    plugins: $store.configuration.plugins,
                                    targetID: plugin.id,
                                    draggingID: $draggingPluginID
                                ))
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                Divider()

                // Add/Remove buttons
                HStack(spacing: 4) {
                    Button {
                        choosePlugin()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        if let id = selectedPluginID {
                            store.removePlugin(id: id)
                            selectedPluginID = nil
                            draft = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedPluginID == nil)

                    Spacer()

                    Button {
                        NSWorkspace.shared.open(store.pluginsDirectoryURL)
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("打开插件文件夹")

                    Button {
                        openPluginHelp()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 12))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("插件编写说明")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(width: 200)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Divider()

            // Plugin detail
            if let draft, draft.id == selectedPluginID {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let lastError = store.lastError {
                                Text(lastError)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            PluginSettingsCard(
                                plugin: draftBinding,
                                enabled: pluginEnabledBinding(draft),
                                pluginsDirectoryURL: store.pluginsDirectoryURL
                            ) {
                                reloadDraftMetadata()
                            } onRemove: {
                                store.removePlugin(id: draft.id)
                                selectedPluginID = nil
                                self.draft = nil
                            }
                        }
                        .padding(20)
                    }

                    Divider()

                    // Save / Reset buttons
                    HStack {
                        Spacer()
                        Button("重置") {
                            loadDraft(for: draft.id)
                        }
                        .disabled(!hasChanges)
                        Button("保存") {
                            saveDraft()
                        }
                        .disabled(!hasChanges)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("选择一个插件查看配置")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minHeight: 400)
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = store.configuration.plugins.first?.id
            }
            if let id = selectedPluginID {
                loadDraft(for: id)
            }
        }
    }

    private var draftBinding: Binding<PluginConfiguration> {
        Binding(
            get: { draft ?? PluginConfiguration(name: "", executablePath: "") },
            set: { draft = $0 }
        )
    }

    private func loadDraft(for id: UUID) {
        selectedPluginID = id
        if let plugin = store.configuration.plugins.first(where: { $0.id == id }) {
            draft = plugin
        }
    }

    private func saveDraft() {
        guard let draft else { return }
        guard let index = store.configuration.plugins.firstIndex(where: { $0.id == draft.id }) else { return }
        store.configuration.plugins[index] = draft
        store.saveConfiguration()
    }

    private func reloadDraftMetadata() {
        guard let draft else { return }
        let fileURL = URL(fileURLWithPath: draft.executablePath)
        let metadata = PluginMetadataParser.parse(fileURL: fileURL)
        var updated = draft
        updated.metadata = metadata
        for parameter in metadata?.parameters ?? [] where updated.parameterValues[parameter.name] == nil {
            updated.parameterValues[parameter.name] = parameter.defaultValue ?? ""
        }
        self.draft = updated
    }

    private func pluginListRow(_ plugin: PluginConfiguration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 12))
                .foregroundStyle(selectedPluginID == plugin.id ? Color.accentColor : .secondary)
                .frame(width: 16)
            Text(plugin.name.isEmpty ? "Untitled" : plugin.name)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: pluginEnabledBinding(plugin))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func pluginEnabledBinding(_ plugin: PluginConfiguration) -> Binding<Bool> {
        Binding(
            get: {
                store.configuration.plugins.first(where: { $0.id == plugin.id })?.enabled ?? false
            },
            set: { newValue in
                store.setPluginEnabled(id: plugin.id, enabled: newValue)
            }
        )
    }

    private func choosePlugin() {
        store.ensurePluginsDirectory()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.pluginsDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            store.addPlugin(fileURL: url)
            let newID = store.configuration.plugins.last?.id
            selectedPluginID = newID
            if let newID { loadDraft(for: newID) }
        }
    }

    private func openPluginHelp() {
        if let url = Bundle.main.url(forResource: "PluginAuthoringGuide", withExtension: "html") {
            NSWorkspace.shared.open(url)
            return
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/PluginAuthoringGuide.html")
        if FileManager.default.fileExists(atPath: developmentURL.path) {
            NSWorkspace.shared.open(developmentURL)
            return
        }

        store.lastError = "未找到插件编写说明文档"
    }
}

// MARK: - About View

struct AboutView: View {
    @ObservedObject var store: UsageBoardStore

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }

    var body: some View {
        SettingsSection {
            SettingsRow(label: "版本") {
                HStack(spacing: 8) {
                    Text(currentVersion)
                        .foregroundStyle(.secondary)
                    Button(store.isUpdating ? "更新中..." : (store.availableUpdate != nil ? "更新可用" : "检查更新")) {
                        if store.availableUpdate != nil {
                            showUpdateAlert(store.availableUpdate!)
                        } else {
                            store.checkForUpdates()
                        }
                    }
                    .controlSize(.small)
                    .disabled(store.isUpdating)
                    if store.isUpdating {
                        ProgressView()
                            .controlSize(.small)
                    } else if let updateMessage = store.updateMessage {
                        Text(updateMessage)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    } else if store.availableUpdate != nil {
                        Text("发现新版本")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
            }

            SettingsRow(label: "说明") {
                Text("聚合展示各类 API 和服务的用量配额")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func showUpdateAlert(_ info: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(info.latestVersion)"
        alert.informativeText = info.notes?.isEmpty == false ? info.notes! : "当前版本 \(currentVersion)，新版本 \(info.latestVersion)。\n是否立即下载并更新？"
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            store.performUpdate()
        }
    }
}

// MARK: - Shared Components

struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SettingsRow<Content: View>: View {
    var label: String
    @ViewBuilder var value: Content

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.primary)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 36)
    }
}

struct PluginSettingsCard: View {
    @Binding var plugin: PluginConfiguration
    var enabled: Binding<Bool>
    var pluginsDirectoryURL: URL
    var onReloadMetadata: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name.isEmpty ? "Untitled" : plugin.name)
                        .font(.system(size: 16, weight: .semibold))
                    if let desc = plugin.metadata?.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("启用", isOn: enabled)
            }

            Divider()

            // Fields
            VStack(alignment: .leading, spacing: 0) {
                pluginRow("名称") {
                    TextField("插件名称", text: $plugin.name)
                        .textFieldStyle(.roundedBorder)
                }

                pluginRow("脚本") {
                    HStack(spacing: 4) {
                        TextField("Python 脚本路径", text: $plugin.executablePath)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            chooseExecutable()
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                        Button {
                            onReloadMetadata()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                pluginRow("刷新间隔") {
                    HStack(spacing: 4) {
                        TextField("秒", value: $plugin.refreshIntervalSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("秒")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Plugin parameters
            if let metadata = plugin.metadata, !metadata.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("插件参数")
                        .font(.system(size: 13, weight: .semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(metadata.parameters) { parameter in
                            PluginParameterField(plugin: $plugin, parameter: parameter)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("未读取到插件参数元数据")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func pluginRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.primary)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = pluginsDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            plugin.executablePath = url.path
        }
    }
}

struct PluginParameterField: View {
    @Binding var plugin: PluginConfiguration
    var parameter: PluginParameterMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 2) {
                    Text(parameter.label)
                        .font(.system(size: 13))
                    if parameter.required {
                        Text("*")
                            .foregroundStyle(.red)
                    }
                }
                .frame(width: 80, alignment: .trailing)
                input
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var input: some View {
        switch parameter.type {
        case .secret:
            SecureField(parameter.placeholder ?? "", text: valueBinding)
                .textFieldStyle(.roundedBorder)
        case .integer:
            TextField(parameter.placeholder ?? "", text: valueBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
        case .boolean:
            Toggle("", isOn: boolBinding)
                .labelsHidden()
        case .choice:
            Picker("", selection: valueBinding) {
                ForEach(parameter.options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        case .string:
            TextField(parameter.placeholder ?? "", text: valueBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var valueBinding: Binding<String> {
        Binding(
            get: { plugin.parameterValues[parameter.name] ?? parameter.defaultValue ?? "" },
            set: { plugin.parameterValues[parameter.name] = $0 }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                let value = plugin.parameterValues[parameter.name] ?? parameter.defaultValue ?? "false"
                return ["1", "true", "yes", "on"].contains(value.lowercased())
            },
            set: { plugin.parameterValues[parameter.name] = $0 ? "true" : "false" }
        )
    }
}

// MARK: - Drag & Drop

struct PluginDropDelegate: DropDelegate {
    @Binding var plugins: [PluginConfiguration]
    let targetID: UUID
    @Binding var draggingID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingID else { return false }
        guard let fromIndex = plugins.firstIndex(where: { $0.id == draggingID }),
              let toIndex = plugins.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else {
            self.draggingID = nil
            return false
        }
        let moved = plugins.remove(at: fromIndex)
        plugins.insert(moved, at: toIndex > fromIndex ? toIndex : toIndex)
        self.draggingID = nil
        return true
    }
}
