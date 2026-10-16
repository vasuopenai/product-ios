import SwiftUI
import FoodGenieKit

enum Loadable<T> {
    case idle, loading, done(T), failed(String)

    var value: T? {
        if case .done(let v) = self { return v }
        return nil
    }
}

/// A question, its answer, and the web search that runs behind the scenes alongside it.
@MainActor
@Observable
final class AskModel {
    enum Filter { case store, all, web }

    var question = ""
    private(set) var asked: String?
    private(set) var answer: Loadable<AskResult> = .idle
    private(set) var web: Loadable<WebResult> = .idle
    var filter: Filter?

    @ObservationIgnored private var askTask: Task<Void, Never>?
    @ObservationIgnored private var webTask: Task<Void, Never>?
    @ObservationIgnored private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var busy: Bool {
        if case .loading = answer { return true }
        return false
    }

    var products: [Product] { answer.value?.products ?? [] }
    var storeCount: Int { products.filter { $0.kroger?.sold == true }.count }
    /// Until the user picks a filter, show the store's products when there are any.
    var view: Filter { filter ?? (storeCount > 0 ? .store : .all) }
    var shown: [Product] { view == .store ? products.filter { $0.kroger?.sold == true } : products }

    func ask(_ text: String, locationId: String?) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        askTask?.cancel()
        webTask?.cancel()
        question = q
        asked = q
        filter = nil
        answer = .loading
        web = .loading

        webTask = Task {
            do {
                let result = try await api.web(q)
                if !Task.isCancelled { web = .done(result) }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { web = .failed(error.userMessage) }
            }
        }
        askTask = Task {
            do {
                let result = try await api.ask(q, locationId: locationId)
                if !Task.isCancelled { answer = .done(result) }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { answer = .failed(error.userMessage) }
            }
        }
    }
}

struct AskView: View {
    @Environment(StoreModel.self) private var store
    @Environment(History.self) private var history
    @Environment(\.openURL) private var openURL
    @State private var model = AskModel(api: AppConfig.api)
    @State private var voice = VoiceInput()
    @FocusState private var focused: Bool

    private let suggestions = [
        "Protein bars with at least 20 g protein and no seed oils",
        "Potato chips cooked in avocado oil",
        "Dark chocolate with more than 70% cocoa",
        "High fiber cereal with no added sugar",
    ]

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: Spacing.m) {
                PageHeader(eyebrow: Format.greeting(), title: "What’re you after?")
                StoreChip()
            }
            .padding(.bottom, Spacing.xl)

            searchField
            voiceNotes

            switch model.answer {
            case .idle: idle
            case .loading: loading
            case .failed(let message):
                EmptyState(icon: "exclamationmark.triangle", title: "That didn’t work", message: message) {
                    AppButton(label: "Try again", kind: .secondary) {
                        if let asked = model.asked { ask(asked) }
                    }
                }
            case .done(let result): results(result)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            voice.onText = { model.question = $0 }
            voice.onFinal = { ask($0) }
        }
    }

    private func ask(_ text: String) {
        focused = false
        history.addQuestion(text)
        model.ask(text, locationId: store.store?.locationId)
    }

    // MARK: Search field

    private var searchField: some View {
        let listening = voice.state == .listening
        let hasText = !model.question.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
            TextField(listening ? "Listening…" : "Protein bars with no seed oils…", text: $model.question, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { ask(model.question) }
                .padding(.vertical, 12)
            if voice.state != .unavailable {
                CircleButton(icon: listening ? "stop.fill" : "mic.fill", filled: listening,
                             label: listening ? "Stop listening" : "Ask by voice") { voice.toggle() }
            }
            CircleButton(icon: "arrow.up", filled: hasText, label: "Ask") { ask(model.question) }
                .disabled(!hasText || model.busy)
        }
        .padding(.leading, Spacing.l)
        .padding(.trailing, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(focused || listening ? Theme.text : .clear, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.15), value: focused)
    }

    @ViewBuilder private var voiceNotes: some View {
        if voice.state == .denied {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                (Text("To ask by voice, allow Microphone and Speech Recognition for Food Genie in Settings. ")
                    .foregroundStyle(Theme.textSecondary)
                 + Text("Open Settings").foregroundStyle(Theme.text).bold())
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }
            .padding(.top, Spacing.s)
        }
        if let error = voice.error {
            Text(error).font(.footnote).foregroundStyle(Theme.textSecondary).padding(.top, Spacing.s)
        }
    }

    // MARK: States

    @ViewBuilder private var idle: some View {
        if !history.questions.isEmpty {
            SectionTitle(title: "Recent") { clearButton { history.clearQuestions() } }
            FlowLayout {
                ForEach(history.questions.prefix(8), id: \.self) { q in
                    Button {
                        Haptics.tap()
                        ask(q)
                    } label: {
                        Chip(label: q, icon: "clock")
                    }
                    .buttonStyle(PressStyle())
                    .contextMenu {
                        Button("Remove", systemImage: "trash", role: .destructive) { history.removeQuestion(q) }
                    }
                }
            }
        }

        if !history.scans.isEmpty {
            SectionTitle(title: "Recently scanned") { clearButton { history.clearScans() } }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(history.scans) { scan in
                        RecentScanTile(scan: scan)
                            .contextMenu {
                                Button("Remove", systemImage: "trash", role: .destructive) { history.removeScan(scan.code) }
                            }
                    }
                }
            }
            .scrollClipDisabled()
        }

        SectionTitle("Try asking")
        VStack(spacing: Spacing.s) {
            ForEach(suggestions, id: \.self) { s in
                Button {
                    Haptics.tap()
                    ask(s)
                } label: {
                    HStack(spacing: Spacing.m) {
                        Text(s).font(.callout).foregroundStyle(Theme.text).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 2)
                    .card()
                }
                .buttonStyle(PressStyle())
            }
        }
        if store.store == nil {
            Text(store.noStores ? "No supported store nearby, so results show without prices and aisles."
                 : "Choose your store to see shelf prices and aisles. Optional: products show either way.")
                .font(.footnote).foregroundStyle(Theme.textSecondary).padding(.top, Spacing.l)
        }
    }

    /// The small "Clear" at the right of a history section title.
    private func clearButton(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text("Clear").font(.footnote.weight(.semibold))
        }
    }

    private let columns = [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)]

    @ViewBuilder private var loading: some View {
        LazyVGrid(columns: columns, spacing: Spacing.m) {
            ForEach(0..<4, id: \.self) { _ in Skeleton(height: 250, radius: Radius.l) }
        }
        .padding(.top, Spacing.xl)
        SectionTitle("From the web")
        webSection
    }

    @ViewBuilder private func results(_ result: AskResult) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                if model.storeCount > 0 {
                    FilterPill(label: "At my store · \(model.storeCount)", selected: model.view == .store) { model.filter = .store }
                }
                FilterPill(label: "All · \(result.products.count)", selected: model.view == .all) { model.filter = .all }
                FilterPill(label: model.web.value.map { "Web · \($0.products.count)" } ?? "Web",
                           selected: model.view == .web) { model.filter = .web }
            }
        }
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.l)

        if model.view == .web {
            webSection
        } else if model.shown.isEmpty {
            EmptyState(icon: "magnifyingglass", title: "No matching products",
                       message: "Try fewer requirements or other words.")
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(model.shown) { ProductTile(product: $0) }
            }
        }
    }

    @ViewBuilder private var webSection: some View {
        switch model.web {
        case .idle:
            EmptyView()
        case .loading:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Searching stores online…").font(.footnote).foregroundStyle(Theme.textTertiary)
                ForEach(0..<2, id: \.self) { _ in Skeleton(height: 76, radius: Radius.l) }
            }
        case .failed(let message):
            Text(message).font(.footnote).foregroundStyle(Theme.textSecondary)
        case .done(let result):
            if result.products.isEmpty {
                Text("Nothing extra found online.").font(.footnote).foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(Array(result.products.enumerated()), id: \.offset) { _, item in WebCard(item: item) }
                }
            }
        }
    }
}

struct FilterPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? Theme.inverse : Theme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selected ? Theme.text : Theme.surface, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
