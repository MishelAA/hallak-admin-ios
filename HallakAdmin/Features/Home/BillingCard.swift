import SwiftUI

/// Home "Billing" card: trial / paid / payment due / overdue. Each count opens Salons filtered by it.
struct BillingCard: View {
    let counts: Overview.BillingCounts
    var open: (BillingStatus) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "creditcard").foregroundStyle(Theme.brandRed).accessibilityHidden(true)
                Text("Billing").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
                Spacer()
                if counts.late > 0 {
                    Text(verbatim: "\(counts.late)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.actionRed))
                        .accessibilityLabel(Text("\(counts.late) late payments"))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 6) {
                cell("Trial", counts.trial, Theme.blue, .trial)
                cell("Paid", counts.active, Theme.green, .active)
                cell("Payment due", counts.grace, Theme.orange, .grace)
                cell("Overdue", counts.overdue, Theme.red, .overdue)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
    }

    private func cell(_ label: LocalizedStringKey, _ value: Int?, _ color: Color, _ status: BillingStatus) -> some View {
        Button {
            Haptics.tap()
            open(status)
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(value ?? 0)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
