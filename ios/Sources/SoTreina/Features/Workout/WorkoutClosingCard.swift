import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Which confirmation card the session shows.
enum ClosingCard: Equatable {
    case discard
    /// `drifted`: the templated workout drifted from its routine, so the card
    /// also asks whether to update the routine
    case finish(drifted: Bool)
}

/// The session's confirmation cards (Claude Design "Treino Academia Foco" 3a
/// and 3b), in place of the iOS action sheet: a floating card with the
/// device's corner radius over the dimmed session, a direct title, one line
/// with the consequence and pill buttons, the main action on top. Red only
/// for the destructive one. A tap on the dim, a drag down or the escape
/// gesture closes it, except while the action runs.
struct WorkoutClosingOverlay: View {
    @Binding var closing: ClosingCard?
    let store: WorkoutStore
    let workout: WorkoutDetail
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var busy = false
    @State private var drag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if closing != nil {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismiss)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            if let closing {
                card(closing)
                    .offset(y: drag)
                    .gesture(dragToDismiss)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.35, bounce: 0.1), value: closing)
        .onChange(of: closing) {
            drag = 0
            busy = false
            store.actionError = nil
        }
    }

    private func card(_ closing: ClosingCard) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.border)
                .frame(width: 36, height: 5)
                .padding(.bottom, 22)
                .accessibilityHidden(true)
            switch closing {
            case .discard:
                DiscardContent(store: store, workout: workout, busy: $busy, onClose: dismiss)
            case let .finish(drifted):
                FinishContent(store: store, workout: workout, drifted: drifted, busy: $busy, onClose: dismiss)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(Color.pageBg, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, y: -8)
        .padding(8)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
    }

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !busy else { return }
                // resists going up, follows going down
                let y = value.translation.height
                drag = y > 0 ? y : y / 6
            }
            .onEnded { value in
                if !busy, value.translation.height > 100 || value.predictedEndTranslation.height > 240 {
                    dismiss()
                } else {
                    withAnimation(.snappy) { drag = 0 }
                }
            }
    }

    private func dismiss() {
        guard !busy else { return }
        closing = nil
    }
}

/// 3a "Cancelar treino?"
private struct DiscardContent: View {
    let store: WorkoutStore
    let workout: WorkoutDetail
    @Binding var busy: Bool
    let onClose: () -> Void

    var body: some View {
        let tally = WorkoutClosing.tally(workout, pending: store.activityPending)
        let minutes = WorkoutClosing.minutes(startedAt: workout.startedAt, now: .now)
        VStack(spacing: 0) {
            CardHeading(title: Text("gym.session.discardTitle", bundle: .l10n), message: message(tally.loggedSets, minutes))
                .padding(.bottom, 24)
            ClosingError(store: store)
            VStack(spacing: 8) {
                Button {
                    busy = true
                    Task {
                        await store.discard()
                        // on success the session is gone; a failure keeps
                        // the card open with the error
                        busy = false
                    }
                } label: {
                    CardButtonLabel(busy: busy) { Text("gym.session.discardConfirm", bundle: .l10n) }
                }
                .buttonStyle(CardButtonStyle(background: .neg, foreground: .white))
                Button(action: onClose) {
                    CardButtonLabel { Text("gym.session.keepTraining", bundle: .l10n) }
                }
                .buttonStyle(CardButtonStyle(background: .chip, foreground: .fg))
            }
            .disabled(busy)
        }
    }

    private func message(_ sets: Int, _ minutes: Int) -> Text {
        switch WorkoutClosing.discardMessage(loggedSets: sets, minutes: minutes) {
        case .empty: Text("gym.session.discardEmpty", bundle: .l10n)
        case let .minutes(m): Text("gym.session.discardMinutes \(m)", bundle: .l10n)
        case let .sets(s): Text("gym.session.discardSets \(s)", bundle: .l10n)
        case let .setsAndMinutes(s, m): Text("gym.session.discardSetsMinutes \(s) \(m)", bundle: .l10n)
        }
    }
}

/// 3b "Finalizar treino?" with the summary so far; a workout that drifted
/// from its routine adds the "Atualizar a rotina" switch (off keeps the
/// routine, the web's "Manter rotina").
private struct FinishContent: View {
    let store: WorkoutStore
    let workout: WorkoutDetail
    let drifted: Bool
    @Binding var busy: Bool
    let onClose: () -> Void
    @State private var syncTemplate = false
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        let tally = WorkoutClosing.tally(workout, pending: store.activityPending)
        VStack(spacing: 0) {
            CardHeading(title: Text("gym.session.finishTitle", bundle: .l10n), message: message(tally))
                .padding(.bottom, 18)
            stats(tally)
                .padding(.bottom, drifted ? 10 : 22)
            if drifted {
                Toggle(isOn: $syncTemplate) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("gym.session.syncTemplateToggle", bundle: .l10n)
                            .font(Font.geist(16, relativeTo: .body).weight(.medium))
                            .foregroundStyle(Color.fg)
                        Text("gym.session.syncTemplateHint", bundle: .l10n)
                            .font(Font.geist(12.5, relativeTo: .caption))
                            .foregroundStyle(Color.mutedFg)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.acc)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.border, lineWidth: 1))
                .disabled(busy)
                .padding(.bottom, 22)
            }
            ClosingError(store: store)
            VStack(spacing: 8) {
                Button {
                    busy = true
                    Task {
                        await store.finish(syncTemplate: drifted && syncTemplate)
                        busy = false
                    }
                } label: {
                    CardButtonLabel(busy: busy) { Text("gym.session.finishSave", bundle: .l10n) }
                }
                .buttonStyle(CardButtonStyle(background: .acc, foreground: .accFg))
                Button(action: onClose) {
                    CardButtonLabel { Text("gym.session.backToWorkout", bundle: .l10n) }
                }
                .buttonStyle(CardButtonStyle(background: .chip, foreground: .fg))
            }
            .disabled(busy || !store.pendingSets.isEmpty)
        }
    }

    private func message(_ tally: WorkoutTally) -> Text {
        switch WorkoutClosing.finishMessage(tally) {
        case .noSets: Text("gym.session.finishNoSets", bundle: .l10n)
        case let .remaining(n): Text("gym.session.finishRemaining \(n)", bundle: .l10n)
        case .allLogged: Text("gym.session.finishAllLogged", bundle: .l10n)
        }
    }

    private func stats(_ tally: WorkoutTally) -> some View {
        let lang = language.lang
        let unit = store.weightUnit
        return HStack(spacing: 0) {
            StatCell(label: Text("gym.session.duration", bundle: .l10n)) {
                // startedAt from the server, like the session header
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(WorkoutFormat.elapsed(Int(context.date.timeIntervalSince(workout.startedAt))))
                }
            }
            StatCell(label: Text("gym.session.finishSets", bundle: .l10n)) {
                Text("\(tally.loggedSets)") + Text("/\(tally.plannedSets)").foregroundStyle(Color.mutedFg)
            }
            StatCell(label: Text("gym.session.finishVolume", bundle: .l10n)) {
                Text(WorkoutFormat.volumeWhole(tally.volumeKg, unit: unit, lang: lang))
                    + Text(" \(UnitConversion.label(unit))")
                    .font(Font.geist(13, relativeTo: .footnote))
                    .foregroundStyle(Color.mutedFg)
            }
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct StatCell<Value: View>: View {
    let label: Text
    @ViewBuilder let value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            label
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
            value
                .font(Font.geistMono(19, relativeTo: .title3).weight(.medium))
                .foregroundStyle(Color.fg)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct CardHeading: View {
    let title: Text
    let message: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(Font.geist(22, relativeTo: .title2).weight(.semibold))
                .kerning(-0.33)
                .foregroundStyle(Color.fg)
                .accessibilityAddTraits(.isHeader)
            message
                .font(Font.geist(14.5, relativeTo: .subheadline))
                .lineSpacing(3)
                .foregroundStyle(Color.mutedFg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

/// A failed discard or finish: the card stays open and says why.
private struct ClosingError: View {
    let store: WorkoutStore

    var body: some View {
        if let error = store.actionError {
            Text(error)
                .font(DSFont.meta)
                .foregroundStyle(Color.neg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
        }
    }
}

private struct CardButtonLabel<Label: View>: View {
    var busy = false
    @ViewBuilder let label: Label

    var body: some View {
        ZStack {
            label.opacity(busy ? 0 : 1)
            if busy { ProgressView() }
        }
    }
}

/// `h-[54px] rounded-full`, 16 semibold — the cards' pill.
private struct CardButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.geist(16, relativeTo: .body).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(foreground)
            .tint(foreground)
            .background(background, in: Capsule())
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
