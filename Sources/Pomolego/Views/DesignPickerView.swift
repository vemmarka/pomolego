import SwiftUI

/// Horizontal strip of design swatches. Locked designs are grayed out with
/// a lock and their unlock threshold.
struct DesignPickerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BlockDesign.catalog) { design in
                    swatch(for: design)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func swatch(for design: BlockDesign) -> some View {
        let unlocked = state.isUnlocked(design)
        let selected = state.selectedDesignID == design.id

        VStack(spacing: 3) {
            ZStack {
                BlockSwatch(design: design)
                    .frame(width: 34, height: 26)
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.35)
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
            )
            Text(design.name)
                .font(.caption2)
                .foregroundStyle(unlocked ? .primary : .secondary)
            if !unlocked {
                Text("at \(design.unlockAt)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { state.selectDesign(design) }
        .accessibilityLabel(unlocked
            ? "\(design.name)\(selected ? ", selected" : "")"
            : "\(design.name), locked, unlocks at \(design.unlockAt) blocks")
        .help(unlocked ? design.name : "Unlocks at \(design.unlockAt) completed blocks")
    }
}
