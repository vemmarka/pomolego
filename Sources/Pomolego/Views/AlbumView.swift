import SwiftUI

/// A photo album of saved fields: the current world plus every archived one
/// (from "Start a fresh canvas"), each rendered as a thumbnail.
struct AlbumView: View {
    @EnvironmentObject var state: AppState
    @State private var confirmingFresh = false

    /// Called after a saved field is opened, so the host can close the window.
    var onPick: () -> Void = {}

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 16) {
                    AlbumCard(blocks: state.world.blocks, title: "Current", date: nil)
                    ForEach(state.worldFile.archived.reversed(), id: \.archivedAt) { archived in
                        AlbumCard(blocks: archived.blocks, title: "Saved", date: archived.archivedAt)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                state.loadArchivedField(archived)
                                onPick()
                            }
                            .onHover { inside in
                                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                            .help("Open this field and keep building")
                    }
                }
                if state.worldFile.archived.isEmpty {
                    Text("No saved fields yet — your archived worlds will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 540, minHeight: 460)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Album").font(.title2.bold())
                Text("Click a saved field to open it and keep building.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Save Current & Start Fresh") { confirmingFresh = true }
                .disabled(state.world.blocks.isEmpty)
        }
        .confirmationDialog("Save the current field and start fresh?",
                            isPresented: $confirmingFresh) {
            Button("Save & Start Fresh", role: .destructive) { state.startFreshCanvas() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current field (\(state.world.blocks.count) blocks) is added to the album and the canvas is cleared.")
        }
    }
}

private struct AlbumCard: View {
    let blocks: [PlacedBlock]
    let title: String
    let date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                let cw = size.width / CGFloat(World.columns)
                let ch = size.height / CGFloat(World.rows)
                var ground = Path()
                ground.move(to: CGPoint(x: 0, y: size.height - 0.5))
                ground.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                context.stroke(ground, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                for b in blocks {
                    let r = CGRect(x: CGFloat(b.col) * cw,
                                   y: CGFloat(World.rows - 1 - b.row) * ch,
                                   width: cw, height: ch)
                    BlockArt.draw(in: context, rect: r, designID: b.designID, isCracked: b.isCracked)
                }
            }
            .aspectRatio(CGFloat(World.columns) / CGFloat(World.rows), contentMode: .fit)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title).font(.callout.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.quaternary.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var subtitle: String {
        let built = blocks.filter { !$0.isCracked }.count
        let cracked = blocks.filter(\.isCracked).count
        var s = ""
        if let date {
            s += date.formatted(date: .abbreviated, time: .shortened) + " · "
        }
        s += "\(built) block\(built == 1 ? "" : "s")"
        if cracked > 0 { s += " · \(cracked) cracked" }
        return s
    }
}
