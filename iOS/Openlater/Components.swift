import SwiftUI

/// The signature hook: a literal wax seal. `.intact` renders a solid, glossy disc
/// with an embossed monogram and no way to see through it. `.breaking` runs the
/// crack-then-melt-open animation exactly once. `.open` renders the same disc split
/// and pushed aside, revealing the content behind it.
struct WaxSealView: View {
    enum Phase { case intact, breaking, open }

    var phase: Phase
    var size: CGFloat = 96
    var onBreakComplete: (() -> Void)? = nil

    @State private var crackProgress: CGFloat = 0
    @State private var splitOffset: CGFloat = 0
    @State private var splitRotation: Double = 0
    @State private var fade: Double = 1

    var body: some View {
        ZStack {
            sealDisc(rotation: -splitRotation, offset: -splitOffset)
                .opacity(fade)
            if phase != .intact {
                sealDisc(rotation: splitRotation, offset: splitOffset)
                    .opacity(fade)
            }
            if phase == .breaking || phase == .open {
                CrackShape(progress: crackProgress)
                    .stroke(OpenlaterColor.waxDeep, lineWidth: max(1.5, size * 0.02))
                    .frame(width: size, height: size)
                    .opacity(phase == .open ? 0 : 1)
            }
        }
        .frame(width: size, height: size)
        .onAppear { if phase == .breaking { runBreakAnimation() } }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .breaking { runBreakAnimation() }
            if newPhase == .open { splitOffset = size * 0.42; splitRotation = 14; fade = 0.94 }
        }
    }

    private func runBreakAnimation() {
        crackProgress = 0
        splitOffset = 0
        splitRotation = 0
        fade = 1
        withAnimation(.easeIn(duration: 0.5)) {
            crackProgress = 1
        }
        withAnimation(.interpolatingSpring(stiffness: 90, damping: 9).delay(0.5)) {
            splitOffset = size * 0.42
            splitRotation = 14
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.9)) {
            fade = 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onBreakComplete?()
        }
    }

    private func sealDisc(rotation: Double, offset: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OpenlaterColor.waxHighlight, OpenlaterColor.wax, OpenlaterColor.waxDeep],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
            Circle()
                .strokeBorder(OpenlaterColor.waxDeep, lineWidth: max(1, size * 0.015))
                .padding(size * 0.06)
            EmbossedMonogram()
                .stroke(OpenlaterColor.waxDeep.opacity(0.85), lineWidth: max(1, size * 0.02))
                .padding(size * 0.3)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .offset(x: offset)
        .shadow(color: .black.opacity(0.25), radius: size * 0.06, y: size * 0.03)
    }
}

/// A simple embossed ring-and-hourglass monogram pressed into the wax — echoes the
/// "time" theme without using any glyph/emoji.
struct EmbossedMonogram: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06))
        let top = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.22)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22)
        let left = CGPoint(x: rect.minX + rect.width * 0.22, y: rect.midY)
        let right = CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.midY)
        path.move(to: top); path.addLine(to: bottom)
        path.move(to: left); path.addLine(to: right)
        return path
    }
}

/// A jagged crack line that grows across the seal as `progress` animates 0 -> 1.
struct CrackShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.1),
            CGPoint(x: rect.midX - rect.width * 0.08, y: rect.midY - rect.height * 0.12),
            CGPoint(x: rect.midX + rect.width * 0.05, y: rect.midY + rect.height * 0.02),
            CGPoint(x: rect.midX - rect.width * 0.04, y: rect.midY + rect.height * 0.18),
            CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.08)
        ]
        var path = Path()
        guard points.count > 1 else { return path }
        let totalSegments = points.count - 1
        let exact = progress * CGFloat(totalSegments)
        let fullSegments = min(totalSegments, Int(exact))
        path.move(to: points[0])
        for i in 1...max(1, fullSegments) where fullSegments > 0 {
            path.addLine(to: points[i])
        }
        if fullSegments < totalSegments {
            let partial = exact - CGFloat(fullSegments)
            let start = points[fullSegments]
            let end = points[fullSegments + 1]
            let mid = CGPoint(x: start.x + (end.x - start.x) * partial, y: start.y + (end.y - start.y) * partial)
            if fullSegments == 0 { path.move(to: start) }
            path.addLine(to: mid)
        }
        return path
    }
}

/// Small "days/hours until unlock" pill shown under a sealed capsule.
struct CountdownPill: View {
    let unlockDate: Date
    let now: Date

    var body: some View {
        Text(label)
            .font(OpenlaterFont.mono(12))
            .foregroundStyle(OpenlaterColor.inkMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(OpenlaterColor.paper)
            .clipShape(SwiftUI.Capsule())
            .overlay(SwiftUI.Capsule().strokeBorder(OpenlaterColor.hairline, lineWidth: 1))
    }

    private var label: String {
        let remaining = CapsuleGating.timeRemaining(now: now, unlockDate: unlockDate)
        if remaining <= 0 { return "Opens now" }
        let days = Int(remaining / 86_400)
        if days > 1 { return "Opens in \(days) days" }
        if days == 1 { return "Opens tomorrow" }
        let hours = max(1, Int(remaining / 3_600))
        return "Opens in \(hours)h"
    }
}

/// Pro badge, gold-on-paper, used sparingly.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(OpenlaterFont.label(10))
            .tracking(1.2)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(OpenlaterColor.gold)
            .clipShape(SwiftUI.Capsule())
    }
}
