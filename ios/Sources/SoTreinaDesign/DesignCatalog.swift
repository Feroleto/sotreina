import SoTreinaKit
import SwiftUI

/// Every design-system piece on one screen, for checking them on the iPhone
/// (light/dark, Dynamic Type) next to the web mobile. Opened from Conta.
public struct DesignCatalog: View {
    @State private var stepper = 20
    @State private var chip = 1

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Esta semana")
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                BigNumber("3", unit: "treinos")
                    .padding(.top, 22)
                HStack {
                    Text("Meta: 4")
                    Spacer()
                    Text("75%").fontWeight(.medium).foregroundStyle(Color.fg)
                }
                .font(Font.geist(12.5, relativeTo: .footnote))
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 12)
                ProgressLine(0.75).padding(.top, 7)
                ProgressLine(1.12).padding(.top, 10)

                KPIStrip([KPI("Volume", "12,4 t"), KPI("Exercícios", "18"), KPI("Tempo", "3h10")])
                    .padding(.top, 22)

                SectionTitle("Próximo treino").padding(.top, 24)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Treino A").font(DSFont.rowTitle)
                            Badge("Próxima")
                        }
                        Text("Peito · Tríceps · há 3 dias").font(DSFont.caption).foregroundStyle(Color.mutedFg)
                    }
                    Spacer()
                    Button("Iniciar") {}.buttonStyle(.pill)
                }
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { Hairline() }

                SectionTitle("Chips").padding(.top, 24)
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Chip(["0,5", "1", "2", "3"][index], selected: chip == index)
                            .onTapGesture { chip = index }
                    }
                }
                .padding(.top, 10)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Corrida").font(DSFont.row)
                        Text("km por semana").font(DSFont.caption).foregroundStyle(Color.mutedFg)
                    }
                    Spacer()
                    ValueStepper(value: $stepper, in: 1...300)
                }
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { Hairline() }
                .padding(.top, 14)

                HStack(spacing: 8) {
                    Button("−15s") {}.buttonStyle(.chip)
                    Button("+15s") {}.buttonStyle(.chip)
                    Spacer()
                    Text("Texto acc-tx").foregroundStyle(Color.accTx).font(DSFont.row)
                }
                .padding(.top, 20)

                HStack(spacing: 14) {
                    Label("pos", systemImage: "checkmark.circle.fill").foregroundStyle(Color.pos)
                    Label("neg", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.neg)
                }
                .font(DSFont.meta)
                .padding(.top, 16)

                ThemePicker().padding(.top, 24)

                Button("Salvar") {}.buttonStyle(.primary).padding(.top, 24)
                Button("Desabilitado") {}.buttonStyle(.primary).disabled(true).padding(.top, 10)
            }
            .padding(.horizontal, pageGutter)
            .padding(.vertical, 12)
        }
        .background(Color.pageBg)
        .navigationTitle("Design system")
        .navigationBarTitleDisplayMode(.inline)
    }
}
