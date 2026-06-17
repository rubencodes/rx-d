import SwiftUI

// Dose "prescription label" card used in the Today list.
struct DoseLabelCard: View {
    let occurrence: ScheduledOccurrence
    let now: Date
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    private var status: DoseStatus { occurrence.effectiveStatus(asOf: now) }
    private var tint: Color { Color(hex: occurrence.prescription.color) }
    private var isTaken: Bool { status == .taken }

    var body: some View {
        LabelCard {
            HStack(spacing: 14) {
                checkButton

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(tint).frame(width: 9, height: 9)
                        Text(occurrence.prescription.name)
                            .font(.headline)
                            .strikethrough(isTaken, color: Theme.inkFaded)
                            .foregroundStyle(isTaken ? Theme.inkFaded : Theme.ink)
                    }
                    HStack(spacing: 6) {
                        Text(occurrence.scheduledDate.formatted(date: .omitted, time: .shortened).uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(Theme.inkFaded)
                        if occurrence.doseLog?.isFromHealth == true {
                            AppleHealthBadge()
                        }
                    }
                }

                Spacer(minLength: 8)

                StatusStamp(status: status, scheduledDate: occurrence.scheduledDate, now: now)
            }
            .padding(14)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(occurrence.prescription.name), \(occurrence.scheduledDate.formatted(date: .omitted, time: .shortened)), \(status.label)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens dose details")
        .accessibilityAction(named: isTaken ? "Mark not taken" : "Mark taken", onToggle)
    }

    private var checkButton: some View {
        Button {
            if reduceMotion { onToggle() }
            else { withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { onToggle() } }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(isTaken ? Theme.taken : tint.opacity(0.55), lineWidth: 2.5)
                    .background(Circle().fill(isTaken ? Theme.taken : Color.clear))
                    .frame(width: 36, height: 36)
                Image(systemName: status.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isTaken ? .white : status.themeColor)
                    .scaleEffect(isTaken ? 1 : 0.9)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}
