/// Card, Chip, buttons, Skeleton, section titles and empty states: the building blocks every screen uses.

import SwiftUI

// MARK: Layout

/// A scrolling page: side gutters, centered max width on iPad, keyboard dismissed by dragging.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
    }
}

/// The large heading at the top of a tab: a quiet line above a bold title.
struct PageHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(eyebrow)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: Card

struct CardBackground: ViewModifier {
    var padded = true

    func body(content: Content) -> some View {
        content
            .padding(padded ? Spacing.l : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }
}

extension View {
    func card(padded: Bool = true) -> some View {
        modifier(CardBackground(padded: padded))
    }

    /// A product tile: one surface with the photo flush to the top, a hairline border and a soft shadow.
    func tileCard() -> some View {
        modifier(TileCard())
    }
}

struct TileCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5)
            }
            .shadow(color: Theme.shadow, radius: 10, y: 4)
    }
}

/// Presses shrink a little, like the system's own cards.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: Buttons

struct AppButton: View {
    enum Kind { case primary, secondary, plain }

    let label: String
    var icon: String?
    var kind: Kind = .primary
    var loading = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.s) {
                if loading {
                    ProgressView().tint(foreground)
                } else if let icon {
                    Image(systemName: icon).font(.body.weight(.semibold))
                }
                Text(label).font(.body.weight(.semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: kind == .plain ? nil : .infinity, minHeight: kind == .plain ? 0 : 50)
            .padding(.horizontal, kind == .plain ? 0 : Spacing.xl)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Theme.border)
                }
            }
        }
        .buttonStyle(PressStyle())
        .disabled(disabled || loading)
        .opacity(disabled ? 0.4 : 1)
    }

    private var foreground: Color {
        kind == .primary ? Theme.inverse : Theme.text
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.text
        case .secondary: Theme.background
        case .plain: .clear
        }
    }
}

/// A round icon button (send, microphone, torch).
struct CircleButton: View {
    let icon: String
    var filled = true
    var size: CGFloat = 36
    var label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(filled ? Theme.inverse : Theme.textSecondary)
                .frame(width: size, height: size)
                .background(filled ? Theme.text : Theme.surfaceStrong, in: Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

// MARK: Chip

struct Chip: View {
    enum Style { case filled, outlined, inverted }

    let label: String
    var icon: String?
    var style: Style = .filled
    /// Gives the icon a meaning color (green, amber, red); a filled chip's background takes a soft wash of it.
    var tint: Color?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(systemName: icon).font(.caption2.weight(.bold)).foregroundStyle(tint ?? labelColor)
            }
            Text(label).font(.footnote.weight(.medium)).lineLimit(1)
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background, in: Capsule())
        .overlay { if style == .outlined { Capsule().strokeBorder(Theme.border) } }
    }

    private var labelColor: Color {
        switch style {
        case .inverted: Theme.inverse
        case .outlined: Theme.textSecondary
        case .filled: Theme.text
        }
    }

    private var background: Color {
        switch style {
        case .inverted: Theme.text
        case .outlined: .clear
        case .filled: tint.map { $0.opacity(0.14) } ?? Theme.surfaceStrong
        }
    }
}

// MARK: Loading and empty states

struct Skeleton: View {
    var height: CGFloat = 16
    var radius: CGFloat = Radius.s
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.surfaceStrong)
            .frame(height: height)
            .opacity(dim ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Spacing.s)
            trailing
        }
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.m)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct EmptyState<Action: View>: View {
    let icon: String
    let title: String
    var message: String?
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.text)
                .frame(width: 60, height: 60)
                .background(Theme.surface, in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            action.padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.l)
    }
}

extension EmptyState where Action == EmptyView {
    init(icon: String, title: String, message: String? = nil) {
        self.init(icon: icon, title: title, message: message) { EmptyView() }
    }
}

/// An icon in a soft circle next to a title and a line of text (scan status, store cards).
struct StatusRow: View {
    let icon: String
    let title: String
    var message: String?
    var busy = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            ZStack {
                Circle().fill(Theme.surfaceStrong)
                if busy {
                    ProgressView().tint(Theme.text)
                } else {
                    Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                }
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.text)
                if let message {
                    Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Flow layout

/// Lays out chips left to right, wrapping to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += min(size.width, bounds.width) + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let w = min(size.width, width)
            if !row.indices.isEmpty && row.width + spacing + w > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + w
            row.height = max(row.height, size.height)
            row.indices.append(i)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
