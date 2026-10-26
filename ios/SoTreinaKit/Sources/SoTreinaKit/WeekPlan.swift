import Foundation

// Plano da semana (.plans/plano-semanal-spec.md §6.1): the API models and the
// rules the Hoje, the editor and the day sheet share. The server resolves
// what is planned on each day (Padrão in force + Ajustes, `GET /plan/days`);
// here that is crossed with what was done. Dates are local calendar days as
// "2026-10-28" strings, the same the API sends.

// MARK: API

public enum PlanEntryState: String, Codable, Equatable, Sendable {
    case planned = "PLANNED"
    /// a Folga
    case skipped = "SKIPPED"
}

public enum PlanSource: String, Codable, Equatable, Sendable {
    case pattern = "PATTERN"
    case adjustment = "ADJUSTMENT"
}

/// One area on one day of `GET /plan/days`. Only RUN and GYM ever appear.
public struct PlanEntry: Codable, Equatable, Sendable {
    public let area: Area
    public let state: PlanEntryState
    public let source: PlanSource
    public let templateId: String?
    public let templateName: String?
    /// set on the planned half of a move: the day it came from
    public let movedFrom: String?
    /// set on the emptied half of a move: the day it went to
    public let movedTo: String?

    public init(
        area: Area, state: PlanEntryState, source: PlanSource, templateId: String?, templateName: String?,
        movedFrom: String?, movedTo: String?
    ) {
        self.area = area
        self.state = state
        self.source = source
        self.templateId = templateId
        self.templateName = templateName
        self.movedFrom = movedFrom
        self.movedTo = movedTo
    }

    public var isMoveHalf: Bool { movedFrom != nil || movedTo != nil }
}

/// `GET /plan/days` — one per day of the range, zero-filled.
public struct PlanDay: Codable, Equatable, Sendable {
    public let date: String
    /// the Padrão in force on this day has at least one slot
    public let active: Bool
    public let entries: [PlanEntry]

    public init(date: String, active: Bool, entries: [PlanEntry]) {
        self.date = date
        self.active = active
        self.entries = entries
    }

    public func entry(_ area: Area) -> PlanEntry? { entries.first { $0.area == area } }

    func isPlanned(_ area: Area) -> Bool { active && entry(area)?.state == .planned }
}

public struct PatternSlot: Codable, Equatable, Sendable {
    /// ISO: 1 = Monday … 7 = Sunday
    public let weekday: Int
    public let area: Area
    public let templateId: String?
    public let templateName: String?

    public init(weekday: Int, area: Area, templateId: String?, templateName: String?) {
        self.weekday = weekday
        self.area = area
        self.templateId = templateId
        self.templateName = templateName
    }
}

/// `GET /plan` — the Padrão in force today.
public struct WeekPattern: Codable, Equatable, Sendable {
    /// nil = never had a plan
    public let effectiveFrom: String?
    public let slots: [PatternSlot]

    public init(effectiveFrom: String?, slots: [PatternSlot]) {
        self.effectiveFrom = effectiveFrom
        self.slots = slots
    }

    public var isActive: Bool { !slots.isEmpty }
}

/// `PUT /plan/pattern`. `templateId` always goes out, `null` included.
public struct PatternWriteRequest: Encodable, Equatable, Sendable {
    public struct Slot: Encodable, Equatable, Sendable {
        public let weekday: Int
        public let area: Area
        public let templateId: String?

        public init(weekday: Int, area: Area, templateId: String?) {
            self.weekday = weekday
            self.area = area
            self.templateId = templateId
        }

        private enum CodingKeys: String, CodingKey { case weekday, area, templateId }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(weekday, forKey: .weekday)
            try c.encode(area, forKey: .area)
            try c.encode(templateId, forKey: .templateId)
        }
    }

    public let slots: [Slot]

    public init(slots: [Slot]) { self.slots = slots }
}

/// `PUT /plan/days/:date`. An area left out isn't touched; `nil` undoes its
/// Ajuste (back to the Padrão) and goes out as JSON `null`.
public struct DayChangeRequest: Encodable, Equatable, Sendable {
    public struct Change: Encodable, Equatable, Sendable {
        public let state: PlanEntryState
        public let templateId: String?

        public init(state: PlanEntryState, templateId: String? = nil) {
            self.state = state
            self.templateId = templateId
        }

        private enum CodingKeys: String, CodingKey { case state, templateId }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(state, forKey: .state)
            try c.encode(templateId, forKey: .templateId)
        }
    }

    public let entries: [Area: Change?]

    public init(_ entries: [Area: Change?]) { self.entries = entries }

    private struct AreaKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private enum CodingKeys: String, CodingKey { case entries }

    public func encode(to encoder: Encoder) throws {
        var root = encoder.container(keyedBy: CodingKeys.self)
        var c = root.nestedContainer(keyedBy: AreaKey.self, forKey: .entries)
        for (area, change) in entries {
            let key = AreaKey(stringValue: area.rawValue)
            if let change { try c.encode(change, forKey: key) } else { try c.encodeNil(forKey: key) }
        }
    }
}

/// `POST /plan/moves` — answers 201 with the window, like the `PUT`s answer 200.
public struct PlanMoveRequest: Encodable, Equatable, Sendable {
    public let area: Area
    public let from: String
    public let to: String

    public init(area: Area, from: String, to: String) {
        self.area = area
        self.from = from
        self.to = to
    }
}

// MARK: Dates

/// Arithmetic on "2026-10-28" calendar days. A fixed UTC Gregorian calendar,
/// so a day is always one day whatever the device's zone does (DST).
public enum PlanDate {
    public struct Range: Equatable, Sendable {
        public let from: String
        public let to: String
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func parse(_ date: String) -> Date {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    public static func add(_ days: Int, to date: String) -> String {
        DietFormat.localDate(utc.date(byAdding: .day, value: days, to: parse(date))!, calendar: utc)
    }

    /// ISO weekday: 1 = Monday … 7 = Sunday
    public static func weekday(_ date: String) -> Int {
        (utc.component(.weekday, from: parse(date)) + 5) % 7 + 1
    }

    public static func monday(of date: String) -> String { add(1 - weekday(date), to: date) }

    /// Monday … Sunday of `date`'s week
    public static func week(of date: String) -> [String] {
        let monday = monday(of: date)
        return (0..<7).map { add($0, to: monday) }
    }

    /// The editable window, also what every mutation answers: Monday of this
    /// week through Sunday of the next.
    public static func window(today: String) -> Range {
        let from = monday(of: today)
        return Range(from: from, to: add(13, to: from))
    }

    /// Local midnight of `date` in `calendar` (for formatting and initials).
    public static func localMidnight(_ date: String, calendar: Calendar) -> Date {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private static let shortPt = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    private static let shortEn = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let longPt = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
    private static let longEn = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// "Qua" | "Wed"
    public static func weekdayShort(_ date: String, lang: Lang) -> String {
        (lang == .pt ? shortPt : shortEn)[weekday(date) - 1]
    }

    /// "Quarta" | "Wednesday"
    public static func weekdayLong(_ date: String, lang: Lang) -> String {
        (lang == .pt ? longPt : longEn)[weekday(date) - 1]
    }
}

/// The fixed plan of the `todayPlanned`/`todayRestDay` validation launches
/// (README "Validação visual"): this week and the next, built around today.
/// Treino Mon/Wed/Fri (Peito, any, Costas), Corrida Tue/Thu/Sat; this Friday
/// is a Folga and this Tuesday's run moved to Sunday. Today either gets a
/// Treino and a Corrida, or is a Dia livre.
public enum PlanPreview {
    /// The day the `planDaySheet` launches open: today, or this week's Monday.
    public static func sheetDate(today: String, past: Bool) -> String {
        past ? PlanDate.monday(of: today) : today
    }

    public static func days(today: String, restDay: Bool) -> [PlanDay] {
        let window = PlanDate.window(today: today)
        let thisWeek = PlanDate.week(of: today)
        let sunday = thisWeek[6]
        return (0..<14).map { offset in
            let date = PlanDate.add(offset, to: window.from)
            func gym(_ name: String?) -> PlanEntry {
                PlanEntry(area: .gym, state: .planned, source: .pattern, templateId: nil, templateName: name, movedFrom: nil, movedTo: nil)
            }
            let run = PlanEntry(area: .run, state: .planned, source: .pattern, templateId: nil, templateName: nil, movedFrom: nil, movedTo: nil)
            var entries: [PlanEntry]
            switch PlanDate.weekday(date) {
            case 1: entries = [gym("Peito")]
            case 3: entries = [gym(nil)]
            case 5: entries = [gym("Costas")]
            case 2, 4, 6: entries = [run]
            default: entries = []
            }
            if offset == 1 {
                entries = [PlanEntry(area: .run, state: .skipped, source: .adjustment, templateId: nil, templateName: nil, movedFrom: nil, movedTo: sunday)]
            } else if date == sunday {
                entries = [PlanEntry(area: .run, state: .planned, source: .adjustment, templateId: nil, templateName: nil, movedFrom: thisWeek[1], movedTo: nil)]
            } else if offset == 4 {
                entries = [PlanEntry(area: .gym, state: .skipped, source: .adjustment, templateId: nil, templateName: nil, movedFrom: nil, movedTo: nil)]
            }
            if date == today {
                entries = restDay ? [] : [run, gym("Peito")]
            }
            return PlanDay(date: date, active: true, entries: entries)
        }
    }
}

// MARK: Status

/// How an area stands on a day, the glossary's words.
public enum PlanAreaState: Equatable, Sendable {
    /// planned and done
    case done
    /// planned for today, not done yet
    case pending
    /// planned on a past day, not done (Perdido)
    case missed
    /// planned on a future day
    case upcoming
    /// a Folga, not done
    case skipped
    /// done without being planned (Dia livre or Folga)
    case extra
    /// nothing planned, nothing done (Dia livre)
    case free

    /// planned that day, done or not
    public var isPlanned: Bool { [.done, .pending, .missed, .upcoming].contains(self) }
}

public enum PlanStatus {
    /// What `area` looks like on `day`. Without an active plan (or no day
    /// loaded) every area counts as planned every day, which is the old Hoje.
    /// Dieta is never in the plan: it's planned every day.
    public static func state(_ area: Area, on day: PlanDay?, done: Bool, today: String) -> PlanAreaState {
        if area != .diet, let day, day.active {
            switch day.entry(area)?.state {
            case .planned: break
            case .skipped: return done ? .extra : .skipped
            case nil: return done ? .extra : .free
            }
        }
        if done { return .done }
        let date = day?.date ?? today
        return date < today ? .missed : date == today ? .pending : .upcoming
    }

    public struct AreaState: Equatable, Sendable {
        public let area: Area
        public let state: PlanAreaState

        public init(area: Area, state: PlanAreaState) {
            self.area = area
            self.state = state
        }
    }

    /// One day of the week strip.
    public struct Column: Equatable, Sendable {
        public let date: String
        public let isToday: Bool
        /// the plan was active that day (false = judged the old way)
        public let active: Bool
        /// one per enabled area, in `Area.allCases` order
        public let states: [AreaState]

        public func state(_ area: Area) -> PlanAreaState? { states.first { $0.area == area }?.state }

        /// what gets a bar: everything but Folga and Dia livre
        public var segments: [AreaState] { states.filter { $0.state != .free && $0.state != .skipped } }

        /// nothing to draw but the neutral dash
        public var isRest: Bool { segments.isEmpty }
    }

    /// Monday … Sunday of the current week, crossed with what was done.
    public static func week(
        now: Date, calendar: Calendar, areas: [Area], planDays: [PlanDay], activities: [ActivityListItem],
        workouts: [WorkoutHistoryItem], dietPoints: [DailyHistoryPoint], kcalGoal: Int
    ) -> [Column] {
        let key = { DietFormat.localDate($0, calendar: calendar) }
        let today = key(now)
        let runDays = Set(activities.map { key($0.startDate) })
        // history-stats only lists finished workouts, so every item counts
        let gymDays = Set(workouts.map { key($0.startedAt) })
        let kcalByDay = Dictionary(dietPoints.map { ($0.date, $0.totalKcal) }, uniquingKeysWith: { a, _ in a })
        let byDate = Dictionary(planDays.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let shown = Area.allCases.filter(areas.contains)

        return PlanDate.week(of: today).map { date in
            let day = byDate[date]
            let done: [Area: Bool] = [
                .run: runDays.contains(date),
                .gym: gymDays.contains(date),
                .diet: TodayStatus.isDietDone(kcal: kcalByDay[date] ?? 0, goal: kcalGoal),
            ]
            return Column(
                date: date,
                isToday: date == today,
                active: day?.active == true,
                states: shown.map {
                    AreaState(area: $0, state: state($0, on: day ?? PlanDay(date: date, active: false, entries: []), done: done[$0]!, today: today))
                }
            )
        }
    }

    public struct Progress: Equatable, Sendable {
        /// days the area is planned this week (Ajustes included)
        public let planned: Int
        /// of those, the ones done
        public let doneOnPlanned: Int
        /// days done without being planned; never part of the Meta
        public let extra: Int

        public init(planned: Int, doneOnPlanned: Int, extra: Int) {
            self.planned = planned
            self.doneOnPlanned = doneOnPlanned
            self.extra = extra
        }
    }

    /// "2 de 3 planejados · +1 extra". Days before the plan started don't
    /// count as planned: what was done on them is an Extra.
    public static func progress(_ area: Area, week: [Column]) -> Progress {
        var planned = 0, doneOnPlanned = 0, extra = 0
        for column in week {
            guard let state = column.state(area) else { continue }
            if !column.active {
                if state == .done { extra += 1 }
                continue
            }
            if state.isPlanned { planned += 1 }
            if state == .done { doneOnPlanned += 1 }
            if state == .extra { extra += 1 }
        }
        return Progress(planned: planned, doneOnPlanned: doneOnPlanned, extra: extra)
    }

    public struct NextPlanned: Equatable, Sendable {
        public let date: String
        /// the planned areas that day (RUN/GYM, among the enabled ones)
        public let areas: [Area]
        /// the Treino's routine, when one is set
        public let templateName: String?
    }

    /// The first day after `date` with something planned: "Dia livre ·
    /// próximo: Qua · Treino".
    public static func nextPlannedDay(_ planDays: [PlanDay], after date: String, areas: [Area]) -> NextPlanned? {
        for day in planDays.sorted(by: { $0.date < $1.date }) where day.date > date {
            let planned = [Area.run, .gym].filter { areas.contains($0) && day.isPlanned($0) }
            if !planned.isEmpty {
                return NextPlanned(date: day.date, areas: planned, templateName: planned.contains(.gym) ? day.entry(.gym)?.templateName : nil)
            }
        }
        return nil
    }

    public struct NextGym: Equatable, Sendable {
        /// the routine to start; nil when there are no routines
        public let template: TemplateSummary?
        /// the planned day it belongs to (today included); nil when no Treino
        /// is planned ahead
        public let date: String?

        public init(template: TemplateSummary?, date: String?) {
            self.template = template
            self.date = date
        }
    }

    /// The next Treino by the plan (spec §6.4): today's planned routine, else
    /// the next planned day's, else the rotation (`RoutineFormat.nextRoutine`)
    /// with no date. A planned day without a routine (or with a deleted one)
    /// also uses the rotation. nil without an active plan today: the caller
    /// keeps its old rule.
    public static func nextGym(_ planDays: [PlanDay], templates: [TemplateSummary], today: String, doneToday: Bool) -> NextGym? {
        guard planDays.first(where: { $0.date == today })?.active == true else { return nil }
        let rotation = RoutineFormat.nextRoutine(templates)
        let routine = { (day: PlanDay) in
            day.entry(.gym)?.templateId.flatMap { id in templates.first { $0.id == id } } ?? rotation
        }
        let ahead = planDays
            .sorted { $0.date < $1.date }
            .filter { $0.isPlanned(.gym) && ($0.date > today || ($0.date == today && !doneToday)) }
        guard let next = ahead.first else { return NextGym(template: rotation, date: nil) }
        return NextGym(template: routine(next), date: next.date)
    }

    // MARK: Moves

    public enum MoveRefusal: Equatable, Sendable {
        case sameDay
        /// no active plan on that day
        case noPlan
        /// the area is already planned there
        case alreadyPlanned
        /// it's the emptied half of another move
        case partOfMove
    }

    public struct MoveTarget: Equatable, Sendable {
        public let date: String
        /// nil = a valid destination
        public let refusal: MoveRefusal?
    }

    /// Whether the area planned on `from` can be moved: from today on, and not
    /// already half of a move (the server refuses chained moves).
    public static func canMove(_ area: Area, from: String, window: [PlanDay], today: String) -> Bool {
        guard from >= today, let day = window.first(where: { $0.date == from }), day.isPlanned(area) else { return false }
        return day.entry(area)?.isMoveHalf == false
    }

    /// Every day from today to the end of the window, each with why it can't
    /// take the move, in the server's terms (server/src/plans/plan-rules.ts).
    /// A Folga of the same area is a valid destination: the move replaces it.
    public static func moveTargets(_ area: Area, from: String, window: [PlanDay], today: String) -> [MoveTarget] {
        window
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
            .map { day in
                let refusal: MoveRefusal? =
                    if day.date == from { .sameDay }
                    else if !day.active { .noPlan }
                    else if day.isPlanned(area) { .alreadyPlanned }
                    else if day.entry(area)?.isMoveHalf == true { .partOfMove }
                    else { nil }
                return MoveTarget(date: day.date, refusal: refusal)
            }
    }
}

// MARK: Day sheet

/// What the day sheet (spec §6.5) offers for each area on one day, in the
/// server's terms (server/src/plans/plan-rules.ts): anything it would refuse
/// isn't offered. Past days only take a Folga of what the Padrão planned, or
/// undoing one; a move with a day already past is frozen.
public struct PlanDaySheet: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// `adjusted`: an Ajuste put it there ("ajuste desta semana")
        case planned(templateName: String?, adjusted: Bool)
        /// a Folga
        case skipped
        /// the emptied half of a move: it went to that day
        case movedTo(String)
        /// the planned half of a move: it came from that day
        case movedFrom(String, templateName: String?)
        /// nothing planned
        case free
    }

    public enum Action: Equatable, Hashable, Sendable {
        /// Treino only
        case changeRoutine
        case move
        /// a Folga (the button says "Pular")
        case skip
        /// back to the Padrão; on a move half, both halves
        case undo
        case add
    }

    public struct Row: Equatable, Sendable {
        public let area: Area
        public let kind: Kind
        public let actions: [Action]

        public init(area: Area, kind: Kind, actions: [Action]) {
            self.area = area
            self.kind = kind
            self.actions = actions
        }
    }

    public let date: String
    public let isPast: Bool
    /// Corrida and Treino, among the enabled areas
    public let rows: [Row]

    /// "Folga o dia todo": two areas that can take a Folga
    public var canSkipAll: Bool { rows.filter { $0.actions.contains(.skip) }.count >= 2 }

    /// nil when `date` is outside the window or has no active plan: Ajustes
    /// only exist with a plan.
    public static func make(date: String, window: [PlanDay], areas: [Area], today: String) -> PlanDaySheet? {
        guard let day = window.first(where: { $0.date == date }), day.active else { return nil }
        let past = date < today
        let rows = [Area.run, .gym].filter(areas.contains).map { area -> Row in
            guard let entry = day.entry(area) else {
                return Row(area: area, kind: .free, actions: past ? [] : [.add])
            }
            switch (entry.state, entry.movedFrom, entry.movedTo) {
            case (.planned, let from?, _):
                return Row(area: area, kind: .movedFrom(from, templateName: entry.templateName), actions: !past && from >= today ? [.undo] : [])
            case (.skipped, _, let to?):
                return Row(area: area, kind: .movedTo(to), actions: past ? [] : [.undo])
            case (.skipped, _, _):
                return Row(area: area, kind: .skipped, actions: [.undo])
            case (.planned, _, _):
                let kind = Kind.planned(templateName: entry.templateName, adjusted: entry.source == .adjustment)
                if past { return Row(area: area, kind: kind, actions: entry.source == .pattern ? [.skip] : []) }
                var actions: [Action] = area == .gym ? [.changeRoutine] : []
                if PlanStatus.canMove(area, from: date, window: window, today: today) { actions.append(.move) }
                actions.append(.skip)
                return Row(area: area, kind: kind, actions: actions)
            }
        }
        return PlanDaySheet(date: date, isPast: past, rows: rows)
    }
}

/// One Ajuste from the day sheet: the request it sends and what the window
/// should look like once it lands, shown at once (the server's window then
/// replaces it). The guess is best effort: undoing a Folga can't know the
/// Padrão's routine, so it shows none until the answer comes.
public enum PlanChange: Equatable, Sendable {
    case day(String, [Area: DayChangeRequest.Change?])
    case move(Area, from: String, to: String)

    public static func skip(_ area: Area, on date: String) -> PlanChange { .day(date, [area: .init(state: .skipped)]) }
    public static func skipAll(_ areas: [Area], on date: String) -> PlanChange {
        .day(date, Dictionary(uniqueKeysWithValues: areas.map { ($0, .some(.init(state: .skipped))) }))
    }
    public static func undo(_ area: Area, on date: String) -> PlanChange { .day(date, [area: nil]) }
    public static func add(_ area: Area, on date: String) -> PlanChange { .day(date, [area: .init(state: .planned)]) }
    /// nil = any routine
    public static func routine(_ templateId: String?, on date: String) -> PlanChange {
        .day(date, [.gym: .init(state: .planned, templateId: templateId)])
    }

    public enum Route: Equatable, Sendable {
        /// `PUT /plan/days/:date`
        case day(String, DayChangeRequest)
        /// `POST /plan/moves`
        case move(PlanMoveRequest)
    }

    public var route: Route {
        switch self {
        case .day(let date, let entries): .day(date, DayChangeRequest(entries))
        case .move(let area, let from, let to): .move(PlanMoveRequest(area: area, from: from, to: to))
        }
    }

    public func applied(to window: [PlanDay], templateNames: [String: String]) -> [PlanDay] {
        var entries = Dictionary(window.map { ($0.date, Dictionary($0.entries.map { ($0.area, $0) }, uniquingKeysWith: { a, _ in a })) }, uniquingKeysWith: { a, _ in a })
        func adjustment(_ area: Area, _ state: PlanEntryState, templateId: String? = nil, templateName: String? = nil, from: String? = nil, to: String? = nil) -> PlanEntry {
            PlanEntry(area: area, state: state, source: .adjustment, templateId: templateId, templateName: templateName, movedFrom: from, movedTo: to)
        }
        func pattern(_ area: Area, templateId: String?, templateName: String?) -> PlanEntry {
            PlanEntry(area: area, state: .planned, source: .pattern, templateId: templateId, templateName: templateName, movedFrom: nil, movedTo: nil)
        }

        switch self {
        case .move(let area, let from, let to):
            let source = entries[from]?[area]
            entries[from]?[area] = adjustment(area, .skipped, to: to)
            entries[to]?[area] = adjustment(area, .planned, templateId: source?.templateId, templateName: source?.templateName, from: from)
        case .day(let date, let changes):
            for (area, change) in changes {
                let current = entries[date]?[area]
                switch change {
                case .some(let change) where change.state == .skipped:
                    entries[date]?[area] = adjustment(area, .skipped)
                case .some(let change):
                    let name = change.templateId.flatMap { templateNames[$0] }
                    entries[date]?[area] = adjustment(area, .planned, templateId: change.templateId, templateName: name)
                case .none:
                    if let to = current?.movedTo {
                        // the emptied half: the routine comes back from the other day
                        let moved = entries[to]?[area]
                        entries[date]?[area] = pattern(area, templateId: moved?.templateId, templateName: moved?.templateName)
                        entries[to]?[area] = nil
                    } else if let from = current?.movedFrom {
                        entries[from]?[area] = pattern(area, templateId: current?.templateId, templateName: current?.templateName)
                        entries[date]?[area] = nil
                    } else {
                        entries[date]?[area] = pattern(area, templateId: nil, templateName: nil)
                    }
                }
            }
        }
        return window.map { day in
            let byArea = entries[day.date] ?? [:]
            return PlanDay(date: day.date, active: day.active, entries: Area.allCases.compactMap { byArea[$0] })
        }
    }
}

// MARK: Editor

/// The Padrão being edited (spec §6.6): lives in memory, saved in one call.
/// Holds the slots of every area, so one hidden by a disabled area survives
/// the save.
public struct PatternDraft: Equatable, Sendable {
    private struct Key: Hashable, Sendable {
        let weekday: Int
        let area: Area
    }

    /// slot → routine (nil = any routine)
    private var slots: [Key: String?]
    private let original: [Key: String?]

    public init(_ pattern: WeekPattern) {
        var slots: [Key: String?] = [:]
        for slot in pattern.slots { slots[Key(weekday: slot.weekday, area: slot.area)] = .some(slot.templateId) }
        self.slots = slots
        original = slots
    }

    public var isDirty: Bool { slots != original }

    public func isOn(_ weekday: Int, _ area: Area) -> Bool { slots[Key(weekday: weekday, area: area)] != nil }

    public func templateId(_ weekday: Int) -> String? { slots[Key(weekday: weekday, area: .gym)] ?? nil }

    /// Turning a Treino off forgets its routine.
    public mutating func toggle(_ weekday: Int, _ area: Area) {
        let key = Key(weekday: weekday, area: area)
        if slots[key] != nil { slots[key] = nil } else { slots[key] = .some(nil) }
    }

    /// Only on a Treino that is on; nil = any routine.
    public mutating func setTemplate(_ weekday: Int, _ templateId: String?) {
        let key = Key(weekday: weekday, area: .gym)
        guard slots[key] != nil else { return }
        slots[key] = .some(templateId)
    }

    public var gymDays: Int { slots.keys.filter { $0.area == .gym }.count }

    /// Saving an empty grid turns the plan off.
    public var isEmpty: Bool { slots.isEmpty }

    /// Empty as far as the editor can show: no slot among `areas`.
    public func isEmpty(among areas: [Area]) -> Bool { !slots.keys.contains { areas.contains($0.area) } }

    public var request: PatternWriteRequest {
        let order = Area.allCases
        return PatternWriteRequest(slots: slots
            .sorted { ($0.key.weekday, order.firstIndex(of: $0.key.area)!) < ($1.key.weekday, order.firstIndex(of: $1.key.area)!) }
            .map { .init(weekday: $0.key.weekday, area: $0.key.area, templateId: $0.value) })
    }
}

/// The 1–2 letters a Treino dot shows for its routine.
public enum RoutineAbbreviation {
    private static let connectives: Set<String> = ["e", "de", "da", "do", "das", "dos", "and", "&", "+", "/", "-"]

    private static func base(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init).filter { !connectives.contains($0.lowercased()) }
        if words.count >= 2 { return words.prefix(2).map { $0.prefix(1).uppercased() }.joined() }
        return name.prefix(1).uppercased()
    }

    /// Initials, or the first letter; names that would collide get the first
    /// letter plus the first one that sets each apart ("Peito" → "Pi",
    /// "Pernas" → "Pr").
    public static func make(_ names: [String]) -> [String: String] {
        let unique = Array(Set(names))
        var result: [String: String] = [:]
        for name in unique {
            let mine = base(name)
            let rivals = unique.filter { $0 != name && base($0) == mine }
            guard !rivals.isEmpty else { result[name] = mine; continue }
            let letters = Array(name.lowercased())
            let others = rivals.map { Array($0.lowercased()) }
            let index = (1..<max(letters.count, 1)).first { i in
                letters[i] != " " && others.allSatisfy { i >= $0.count || $0[i] != letters[i] }
            }
            result[name] = index.map { mine.prefix(1) + String(letters[$0]) } ?? mine
        }
        return result
    }
}
