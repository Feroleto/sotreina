import MapKit
import SoTreinaDesign
import SoTreinaKit
import SwiftUI
import UIKit

/// Corrida › Atividades › a run (web ActivityDetailView, mobile): name, date
/// and "View on Strava", the six headline stats, the route on MapKit (a grid
/// placeholder for a treadmill run), the laps and "Powered by Strava". The
/// list row draws the header at once; stats and laps come from
/// `GET /activities/:id` (cached).
struct RunActivityDetailView: View {
    let item: ActivityListItem
    let store: RunStore
    @State private var detail: ActivityDetail?
    @State private var failure: String?
    @Environment(SessionStore.self) private var session
    @Environment(AppLanguageStore.self) private var language

    private let calendar = Calendar.current

    var body: some View {
        let lang = language.lang
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(detail?.name ?? item.name)
                    .font(Font.geist(22, relativeTo: .title2).weight(.semibold))
                    .tracking(-0.44)
                    .foregroundStyle(Color.fg)
                    .padding(.top, 8)

                FlowLayout(spacing: 12) {
                    Text(verbatim: RunFormat.dateFull(item.startDate, lang: lang, calendar: calendar))
                        .foregroundStyle(Color.mutedFg)
                    if let detail {
                        // brand guidelines: this exact text (not translated),
                        // marked as a link by Strava orange and bold
                        Link(destination: detail.stravaURL) {
                            Text(verbatim: "View on Strava")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(red: 0xFC / 255, green: 0x52 / 255, blue: 0))
                        }
                    }
                }
                .font(DSFont.meta)
                .padding(.top, 3)

                stats(lang)
                    .padding(.top, 22)

                RouteCard(route: detail?.route, loaded: detail != nil)
                    .padding(.top, 22)

                if let detail {
                    LapsTable(detail: detail, unit: session.distanceUnit)
                        .padding(.top, 28)
                } else if let failure {
                    Text(failure)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.neg)
                        .padding(.top, 28)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }

                PoweredByStrava()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, pageGutter)
        }
        .background(Color.pageBg)
        .navigationTitle(Text(verbatim: ""))
        .floatingTabBarSpace()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                WorkoutTypeBadge(workoutType: item.workoutType)
            }
        }
        .taskOnTabActivation {
            detail = detail ?? store.cachedDetail(item.id)
            switch await store.detail(item.id) {
            case .success(let fresh): detail = fresh
            case .failure(let error): if detail == nil { failure = error.message }
            }
        }
    }

    /// The mobile grid: the web's eight minus max HR and best pace
    /// (`desktopOnly`). The list row already carries the totals, so the
    /// grid draws before the detail answers.
    private func stats(_ lang: Lang) -> some View {
        let unit = session.distanceUnit
        let source = detail.map {
            (km: $0.distanceKm, sec: $0.movingTimeSec, pace: $0.paceRawSecKm, elev: $0.elevationGainM, hr: $0.averageBpm, cad: $0.averageCadence)
        } ?? (km: item.distanceKm, sec: item.movingTimeSec, pace: item.paceRawSecKm, elev: item.elevationGainM, hr: item.averageBpm, cad: item.averageCadence)
        let cards: [(String, String)] = [
            ("activity.stats.distance", source.km.map { "\(RunFormat.distance($0, unit: unit, lang: lang)) \(UnitConversion.label(unit))" } ?? "—"),
            ("activity.stats.time", WorkoutFormat.durationShort(source.sec)),
            ("activity.stats.pace", RunFormat.pace(source.pace, unit: unit)),
            ("activity.stats.elevation", source.elev.map { "\(Int($0.rounded())) m" } ?? "—"),
            ("activity.stats.avgHr", source.hr.map { "\(Int($0.rounded())) bpm" } ?? "—"),
            ("activity.stats.cadence", source.cad.map { "\(Int($0.rounded())) spm" } ?? "—"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(cards, id: \.0) { key, value in
                StatCard(label: L10n.string(key, lang: lang), value: value)
            }
        }
    }
}

/// caps label over a semibold value on a bordered card (`rounded-xl border bg-card`)
private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Font.geist(11, relativeTo: .caption2))
                .tracking(0.33)
                .textCase(.uppercase)
                .foregroundStyle(Color.mutedFg)
            Text(verbatim: value)
                .font(Font.geist(17, relativeTo: .headline).weight(.semibold))
                .foregroundStyle(Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// The type pill by the back button (`WORKOUT_META` badge colors).
private struct WorkoutTypeBadge: View {
    let workoutType: String
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let (fg, bg): (Color, Color) = switch workoutType {
        case "INTERVAL": (.accTx, .accBg)
        case "HILL_REPEATS": (.pos, Self.posBg)
        // --neutral is the muted foreground's value in both themes
        default: (.mutedFg, Self.neutralBg)
        }
        Text(verbatim: RunFormat.workoutTypeKey(workoutType).map { L10n.string($0, lang: language.lang) } ?? workoutType)
            .font(Font.geist(11.5, relativeTo: .caption).weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg, in: Capsule())
            .fixedSize()
    }

    /// `--neutral-bg`: rgba(21,21,21,.06) light, rgba(255,255,255,.08) dark
    private static let neutralBg = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(red: 21 / 255, green: 21 / 255, blue: 21 / 255, alpha: 0.06)
    })

    /// `--pos-bg`: `--pos` at 10% light, 14% dark
    private static let posBg = Color(uiColor: UIColor { traits in
        monolitoUIColor(.pos).resolvedColor(with: traits)
            .withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.14 : 0.1)
    })
}

/// The route at 8:3 like the web's map: mustard line, green start, foreground
/// end, both ringed in the card color. Static (no pan or zoom), so the page
/// scrolls over it. Without a route, the web's grid with "Sem dados de GPS".
private struct RouteCard: View {
    let route: [LatLng]?
    /// before the detail answers there's no telling GPS from treadmill
    let loaded: Bool

    var body: some View {
        Group {
            if let route {
                let coords = route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
                Map(initialPosition: .automatic, interactionModes: []) {
                    MapPolyline(coordinates: coords)
                        .stroke(Color.acc, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    Annotation("", coordinate: coords[0], anchor: .center) { RouteDot(fill: .pos) }
                        .annotationTitles(.hidden)
                    Annotation("", coordinate: coords[coords.count - 1], anchor: .center) { RouteDot(fill: .fg) }
                        .annotationTitles(.hidden)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            } else if loaded {
                NoGpsGrid()
            } else {
                Color.chip
            }
        }
        .aspectRatio(8 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.border, lineWidth: 1)
        }
    }
}

/// `circleMarker` radius 5.5, stroke 2.5 in the card color
private struct RouteDot: View {
    let fill: Color

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 11, height: 11)
            .overlay { Circle().stroke(Color.card, lineWidth: 2.5) }
    }
}

/// The web's 640×240 placeholder: verticals every 80, horizontals every 60.
private struct NoGpsGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 80.0, through: 560, by: 80) {
                let px = size.width * x / 640
                path.move(to: CGPoint(x: px, y: 0))
                path.addLine(to: CGPoint(x: px, y: size.height))
            }
            for y in stride(from: 60.0, through: 180, by: 60) {
                let py = size.height * y / 240
                path.move(to: CGPoint(x: 0, y: py))
                path.addLine(to: CGPoint(x: size.width, y: py))
            }
            context.stroke(path, with: .color(Color.border), lineWidth: 1)
        }
        .overlay {
            Text("activity.noGps", bundle: .l10n)
                .font(DSFont.meta)
                .foregroundStyle(Color.mutedFg)
        }
    }
}

/// "VOLTAS  16 Voltas", then the mobile columns: #, lap, distance, time,
/// pace and average HR (cadence and max HR are desktop only).
/// Six fixed columns don't survive the largest text sizes (headers break
/// mid-word), so the table stops growing at `.xLarge`; the rest of the
/// page keeps following Dynamic Type.
private struct LapsTable: View {
    let detail: ActivityDetail
    let unit: DistanceUnit
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let lang = language.lang
        let labels = RunFormat.lapLabels(detail.laps)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("activity.laps.title", bundle: .l10n)
                    .font(Font.geist(12, relativeTo: .caption).weight(.semibold))
                    .tracking(0.48)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.mutedFg)
                Spacer()
                Text(verbatim: L10n.string("activity.laps.count %lld", lang: lang, detail.laps.count))
                    .font(Font.geist(12.5, relativeTo: .caption))
                    .foregroundStyle(Color.mutedFg)
            }
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.gridAx).frame(height: 1) }

            if !detail.laps.isEmpty {
                LapRowLayout(
                    index: Text("activity.laps.index", bundle: .l10n),
                    label: Text("activity.laps.lap", bundle: .l10n),
                    distance: Text("activity.laps.dist", bundle: .l10n),
                    time: Text("activity.laps.time", bundle: .l10n),
                    pace: Text("activity.laps.pace", bundle: .l10n),
                    hr: Text("activity.laps.avgHr", bundle: .l10n)
                )
                .font(Font.geist(11, relativeTo: .caption2))
                .tracking(0.33)
                .textCase(.uppercase)
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 9)
                .padding(.bottom, 7)

                ForEach(Array(detail.laps.enumerated()), id: \.element.id) { index, lap in
                    let label = labels[index]
                    let name = L10n.string(label.key, lang: lang)
                    LapRowLayout(
                        index: Text(verbatim: "\(lap.lapIndex)")
                            .font(Font.geist(12.5, relativeTo: .caption))
                            .foregroundStyle(Color.mutedFg),
                        label: Text(verbatim: label.number.map { "\(name) \($0)" } ?? name)
                            .font(Font.geist(13.5, relativeTo: .subheadline).weight(.medium))
                            .foregroundStyle(Color.fg),
                        distance: Text(verbatim: "\(RunFormat.lapDistance(lap.distanceM, unit: unit, lang: lang)) \(UnitConversion.label(unit))"),
                        time: Text(verbatim: RunFormat.minSec(lap.movingDurationSec)),
                        pace: Text(verbatim: RunFormat.paceValue(lap.avgPaceSecKm, unit: unit))
                            .font(Font.geist(13.5, relativeTo: .subheadline).weight(.semibold))
                            .foregroundStyle(Color.fg),
                        hr: Text(verbatim: lap.avgHr > 0 ? "\(Int(lap.avgHr.rounded()))" : "—")
                    )
                    .font(Font.geist(13, relativeTo: .footnote))
                    .foregroundStyle(Color.mutedFg)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// The column widths of the web's mobile table; the lap name takes the rest.
private struct LapRowLayout: View {
    let index: Text
    let label: Text
    let distance: Text
    let time: Text
    let pace: Text
    let hr: Text

    var body: some View {
        HStack(spacing: 6) {
            index.frame(width: 22, alignment: .leading)
            label.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            distance.lineLimit(1).frame(width: 62, alignment: .trailing)
            time.lineLimit(1).frame(width: 44, alignment: .trailing)
            pace.lineLimit(1).frame(width: 56, alignment: .trailing)
            // wider than the web's 44: the caps "FC MÉDIA" and its tracking
            hr.lineLimit(1).frame(width: 52, alignment: .trailing)
        }
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 2)
    }
}
