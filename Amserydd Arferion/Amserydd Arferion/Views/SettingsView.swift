import SwiftUI

struct SettingsView: View {
    @AppStorage("debtMode") private var debtMode = "stopAtZero"
    @AppStorage("debtRecoveryMultiplier") private var debtRecoveryMultiplier = 1.5
    @State private var showDebtExplanation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("When the bank is empty", selection: $debtMode) {
                        Text("Stop at zero").tag("stopAtZero")
                        Text("Allow debt").tag("allowDebt")
                    }
                    .pickerStyle(.segmented)

                    if debtMode == "allowDebt" {
                        Stepper(value: $debtRecoveryMultiplier, in: 1...3, step: 0.25) {
                            HStack {
                                Text("Debt recovery")
                                Spacer()
                                Text("\(debtRecoveryMultiplier.formatted(.number.precision(.fractionLength(0...2))))×")
                                    .font(.headline.monospacedDigit())
                            }
                        }

                        Button {
                            showDebtExplanation = true
                        } label: {
                            Label("How debt recovery works", systemImage: "info.circle")
                        }
                    }
                } header: {
                    Text("Spending rules")
                } footer: {
                    Text(footerText)
                }

                Section("Data") {
                    Label("Stored only on this device", systemImage: "iphone")
                    Text("There is no account or cloud sync in this version.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("App", value: "Amserydd Arferion")
                    LabeledContent("Version", value: "0.1")
                }
            }
            .scrollContentBackground(.hidden)
            .background(GorpcoreTheme.background)
            .navigationTitle("Settings")
            .alert("Debt recovery", isPresented: $showDebtExplanation) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("At 1.5×, clearing one minute of debt requires enough good-habit activity to earn 90 seconds normally. The penalty applies only while your balance is below zero.")
            }
        }
    }

    private var footerText: String {
        if debtMode == "allowDebt" {
            return "Spending may take the balance below zero. Earned time is discounted by the recovery multiplier until the debt is cleared."
        }
        return "Spend timers stop automatically when your available time reaches zero."
    }
}
