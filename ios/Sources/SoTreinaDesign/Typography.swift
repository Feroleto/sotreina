import SwiftUI

/// The web mobile's text sizes (Tailwind classes of the Monolito screens),
/// all scaling with Dynamic Type from these base sizes.
public enum DSFont {
    /// area header (`text-[28px] font-semibold tracking-[-.02em]`)
    public static let pageTitle = Font.geist(28, relativeTo: .largeTitle).weight(.semibold)
    /// highlight number (`font-mono text-[64px] font-medium tracking-[-.05em]`)
    public static let bigNumber = Font.geistMono(64, relativeTo: .largeTitle).weight(.medium)
    /// unit next to the big number (`text-[17px] text-muted-foreground`)
    public static let bigNumberUnit = Font.geist(17, relativeTo: .title3)
    /// KPI value (`font-mono text-[20px] font-medium`)
    public static let kpiValue = Font.geistMono(20, relativeTo: .title3).weight(.medium)
    /// KPI label, meta lines (`text-[12px]`)
    public static let caption = Font.geist(12, relativeTo: .caption)
    /// subtitle under the header (`text-[13px]`)
    public static let meta = Font.geist(13, relativeTo: .footnote)
    /// section title (`text-[14px] font-semibold`)
    public static let sectionTitle = Font.geist(14, relativeTo: .subheadline).weight(.semibold)
    /// highlighted row title (`text-[17px] font-semibold tracking-[-.01em]`)
    public static let rowTitle = Font.geist(17, relativeTo: .headline).weight(.semibold)
    /// list row title (`text-[14.5px] font-medium`)
    public static let row = Font.geist(14.5, relativeTo: .subheadline).weight(.medium)
    /// running text
    public static let body = Font.geist(15, relativeTo: .body)
    /// numbers inside rows (set lines, inputs)
    public static let monoBody = Font.geistMono(15, relativeTo: .body)
    /// buttons (`text-[14px] font-semibold`; pills 13.5)
    public static let button = Font.geist(14, relativeTo: .subheadline).weight(.semibold)
    public static let pill = Font.geist(13.5, relativeTo: .subheadline).weight(.semibold)
}

extension View {
    /// The big-number tracking (-0.05em) needs the size: 64 × 0.05.
    public func bigNumberStyle() -> some View {
        font(DSFont.bigNumber).tracking(-3.2).foregroundStyle(Color.fg)
    }
}
