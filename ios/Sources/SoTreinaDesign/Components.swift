import SwiftUI

/// Base components of the Monolito screens, mirroring the web mobile:
/// flat page, hairlines instead of cards, mustard only on progress, active
/// state and the primary button.

/// The 22pt page gutter of the web mobile (`px-[22px]`).
public let pageGutter: CGFloat = 22

// MARK: - Numbers

/// "12 treinos": the 64pt Geist Mono figure with its unit.
public struct BigNumber: View {
    let value: String
    let unit: String?

    public init(_ value: String, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value).bigNumberStyle().lineLimit(1).minimumScaleFactor(0.5)
            if let unit {
                Text(unit).font(DSFont.bigNumberUnit).foregroundStyle(Color.mutedFg)
            }
        }
    }
}

public struct KPI: Identifiable {
    public let label: String
    public let value: String
    public var id: String { label }

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// Row of KPIs between two hairlines, split by vertical ones
/// (`grid grid-cols-3 border-y`).
public struct KPIStrip: View {
    let items: [KPI]

    public init(_ items: [KPI]) { self.items = items }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Hairline(axis: .vertical) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label).font(DSFont.caption).foregroundStyle(Color.mutedFg)
                    Text(item.value).font(DSFont.kpiValue).foregroundStyle(Color.fg)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.leading, index > 0 ? 14 : 0)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - Lines and progress

/// 1px line in `--border`.
public struct Hairline: View {
    let axis: Axis

    public init(axis: Axis = .horizontal) { self.axis = axis }

    public var body: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }
}

/// Thin progress line (`h-[3px] bg-border`, fill `bg-acc`); past the goal it
/// turns `--neg`, the web's over-goal rule.
public struct ProgressLine: View {
    let fraction: Double
    let height: CGFloat

    public init(_ fraction: Double, height: CGFloat = 3) {
        self.fraction = fraction
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.border)
                Capsule()
                    .fill(fraction > 1 ? Color.neg : Color.acc)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((fraction * 100).rounded()))%"))
    }
}

// MARK: - Chips and badges

/// Rounded chip (`rounded-full bg-chip`); selected = `border-acc bg-acc-bg text-acc-tx`.
public struct Chip: View {
    let label: String
    let selected: Bool

    public init(_ label: String, selected: Bool = false) {
        self.label = label
        self.selected = selected
    }

    public var body: some View {
        Text(label)
            .font(Font.geist(12.5, relativeTo: .footnote).weight(.medium))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Color.accTx : Color.mutedFg)
            .background(selected ? Color.accBg : Color.chip, in: Capsule())
            .overlay { if selected { Capsule().strokeBorder(Color.acc, lineWidth: 1) } }
    }
}

/// Small tag next to a title ("Próxima", "PR").
public struct Badge: View {
    let label: String

    public init(_ label: String) { self.label = label }

    public var body: some View {
        Text(label)
            .font(Font.geist(11, relativeTo: .caption2).weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Color.accTx)
            .background(Color.accBg, in: Capsule())
    }
}

// MARK: - Stepper

/// − value + with round chip buttons (WeeklyGoalsPage, QuantitySheet).
public struct ValueStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: (Int) -> String

    public init(value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1, format: @escaping (Int) -> String = { "\($0)" }) {
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(spacing: 12) {
            button("minus", enabled: value > range.lowerBound) { value = max(range.lowerBound, value - step) }
                .accessibilityLabel(Text("today.goals.decrease", bundle: .l10n))
            Text(format(value))
                .font(DSFont.kpiValue)
                .foregroundStyle(Color.fg)
                .frame(minWidth: 48)
                .contentTransition(.numericText(value: Double(value)))
            button("plus", enabled: value < range.upperBound) { value = min(range.upperBound, value + step) }
                .accessibilityLabel(Text("today.goals.increase", bundle: .l10n))
        }
        .accessibilityElement(children: .contain)
    }

    private func button(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.chip, in: Circle())
                .foregroundStyle(Color.fg)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Section title

/// "Rotinas", "Próximo treino" (`text-[14px] font-semibold`).
public struct SectionTitle: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text).font(DSFont.sectionTitle).foregroundStyle(Color.fg)
    }
}

// MARK: - Flow

/// Lays children out left to right, wrapping to a new line when the width
/// runs out (`flex flex-wrap gap-[6px]`): the chips of a routine/exercise.
public struct FlowLayout: Layout {
    let spacing: CGFloat

    public init(spacing: CGFloat = 6) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Caps title

/// "EXERCÍCIOS", "COMO EXECUTAR" (`text-[11.5px] font-medium uppercase
/// tracking-[.05em] text-muted-foreground`): a list's header over a hairline.
public struct CapsTitle: View {
    let text: Text

    public init(_ text: Text) { self.text = text }

    public var body: some View {
        text
            .font(Font.geist(11.5, relativeTo: .caption).weight(.medium))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.mutedFg)
    }
}
