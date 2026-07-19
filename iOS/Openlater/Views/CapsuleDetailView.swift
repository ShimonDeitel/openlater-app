import SwiftUI

/// Shows either the locked (seal-only, no content access whatsoever) state or the
/// unlocked content, playing the one-time seal-break animation the first time a
/// ready-to-open capsule is viewed.
struct CapsuleDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let capsule: LetterCapsule

    @State private var sealPhase: WaxSealView.Phase = .intact
    @State private var revealContent = false
    @StateObject private var recorder = VoiceRecorder()
    /// Captured once when the sheet opens so that `markOpened` advancing a
    /// recurring capsule's unlock date mid-view doesn't yank the UI back to the
    /// locked state while the user is still reading what they just unsealed.
    @State private var frozenState: CapsuleGating.State?

    var body: some View {
        NavigationStack {
            ZStack {
                OpenlaterColor.paper.ignoresSafeArea()
                content
            }
            .navigationTitle(capsule.title.isEmpty ? "Letter" : capsule.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        appModel.delete(capsule)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .onAppear(perform: setUpInitialPhase)
        }
    }

    private var state: CapsuleGating.State { frozenState ?? appModel.state(for: capsule) }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .sealed:
            lockedView
        case .readyToBreak, .open:
            unlockedContainer
        }
    }

    private func setUpInitialPhase() {
        if frozenState == nil { frozenState = appModel.state(for: capsule) }
        switch state {
        case .sealed:
            sealPhase = .intact
        case .readyToBreak:
            sealPhase = .intact // will animate to breaking on appear of unlocked container
        case .open:
            sealPhase = .open
            revealContent = true
        }
    }

    // MARK: Locked

    private var lockedView: some View {
        VStack(spacing: 22) {
            Spacer()
            WaxSealView(phase: .intact, size: 160)
            Text("This letter is still sealed")
                .font(OpenlaterFont.serifHeadline())
                .foregroundStyle(OpenlaterColor.ink)
            VStack(spacing: 4) {
                Text("It opens on")
                    .font(OpenlaterFont.body(14))
                    .foregroundStyle(OpenlaterColor.inkMuted)
                Text(capsule.unlockDate.formatted(date: .long, time: .omitted))
                    .font(OpenlaterFont.serifHeadline(20))
                    .foregroundStyle(OpenlaterColor.wax)
            }
            CountdownPill(unlockDate: capsule.unlockDate, now: appModel.clock.now())
            Text("There is no way to peek early — not even for you.")
                .font(OpenlaterFont.mono(11))
                .foregroundStyle(OpenlaterColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(24)
    }

    // MARK: Unlocked

    private var unlockedContainer: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            WaxSealView(phase: sealPhase, size: 140) {
                withAnimation(.easeOut(duration: 0.4)) { revealContent = true }
                appModel.markOpened(capsule)
            }
            .onAppear {
                if state == .readyToBreak && sealPhase == .intact {
                    // Small delay so the user sees the intact seal for a beat before
                    // it visibly breaks — a snap, not an instant swap.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        sealPhase = .breaking
                    }
                }
            }

            if revealContent {
                unlockedBody
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("Breaking the seal…")
                    .font(OpenlaterFont.mono(12))
                    .foregroundStyle(OpenlaterColor.inkMuted)
            }
            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private var unlockedBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(capsule.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(OpenlaterFont.mono(11))
                .foregroundStyle(OpenlaterColor.inkMuted)

            switch capsule.kind {
            case .text:
                Text(capsule.textBody)
                    .font(OpenlaterFont.body(17))
                    .foregroundStyle(OpenlaterColor.ink)
            case .photo:
                if let image = MediaStore.loadImage(capsule.mediaFilename) {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if !capsule.textBody.isEmpty {
                    Text(capsule.textBody)
                        .font(OpenlaterFont.body(16))
                        .foregroundStyle(OpenlaterColor.ink)
                }
            case .voice:
                Button {
                    if recorder.isPlaying {
                        recorder.stopPlayback()
                    } else if let filename = capsule.mediaFilename {
                        recorder.play(filename: filename)
                    }
                } label: {
                    Label(recorder.isPlaying ? "Stop" : "Play voice memo", systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
                }
                .letterButton()
            }

            if capsule.recurrence != .none {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Re-seals \(capsule.recurrence == .yearly ? "yearly" : "monthly") — next opening \(capsule.unlockDate.formatted(date: .long, time: .omitted))")
                }
                .font(OpenlaterFont.mono(11))
                .foregroundStyle(OpenlaterColor.gold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OpenlaterColor.paperPanel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
