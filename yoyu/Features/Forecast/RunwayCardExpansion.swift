import SwiftUI

/// An overlay above the home page. Only the card's bounds animate; the shared
/// header is never cross-faded with a second page or scaled as a screenshot.
struct RunwayCardExpansion<Header: View, Details: View>: View {
    let source: CGRect
    let onClose: () -> Void
    @ViewBuilder var header: () -> Header
    @ViewBuilder var details: () -> Details
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var dragProgress: CGFloat = 0
    @State private var dragging = false
    @GestureState private var touchingEdge = false
    @State private var openProgress: CGFloat = 0
    @State private var pressAmount: CGFloat = 1
    @State private var detailVisible = false
    @State private var ready = false
    @State private var closing = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var scrollY: CGFloat = 0

    var body: some View {
        GeometryReader { safe in
            GeometryReader { canvas in
                let bounds = canvas.frame(in: .global)
                let start = source.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
                RunwayAnimationPhase(openProgress: openProgress, pressAmount: pressAmount, dragProgress: dragProgress) { animatedOpen, animatedPress, animatedDrag in
                    let openness = animatedOpen * (1 - animatedDrag)
                    let width = start.width + (canvas.size.width - start.width) * openness
                    let height = start.height + (canvas.size.height - start.height) * openness
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.ultraThinMaterial)
                            .overlay(Color.black.opacity(0.1))
                            .opacity(openness).ignoresSafeArea()
                        ScrollView {
                            VStack(spacing: 0) {
                                header()
                                    .padding(.top, safe.safeAreaInsets.top * openness)
                                details()
                                    .allowsHitTesting(ready && !closing && !dragging)
                                    .padding(.bottom, safe.safeAreaInsets.bottom + 24)
                                    .opacity(detailVisible ? openness : 0)
                            }
                        }
                        .scrollPosition($scroll)
                        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, value in scrollY = value }
                        .scrollDisabled(!ready || closing || dragging)
                        .scrollIndicators(.hidden)
                        .frame(width: width, height: height, alignment: .top)
                        .background {
                            ZStack {
                                Color(uiColor: .systemBackground)
                                LinearGradient(colors: [DashboardStyle.cash.opacity(0.18), DashboardStyle.cash.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28 + 18 * openness, style: .continuous))
                        .shadow(color: .black.opacity(0.22 * openness), radius: 28, y: 10)
                        .modifier(RunwayCardLift(progress: openness, pressAmount: animatedPress, reduceMotion: reduceMotion))
                        .offset(x: start.minX * (1 - openness), y: start.minY * (1 - openness))
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { close() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary).frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                        }
                        .tint(.primary)
                        .padding(.top, safe.safeAreaInsets.top + 12).padding(.trailing, 16)
                        .opacity(detailVisible ? 1 - animatedDrag : 0)
                        .disabled(!ready || closing || dragging)
                        .accessibilityLabel("关闭预测详情").accessibilityIdentifier("runway.closeDetail")
                    }
                    .overlay(alignment: .leading) {
                        Color.clear
                            .frame(width: 24)
                            .contentShape(Rectangle())
                            .gesture(edgeReturn(width: canvas.size.width))
                            .allowsHitTesting(ready && !closing)
                            .accessibilityHidden(true)
                    }
                    .onChange(of: touchingEdge) { _, active in
                        if !active {
                            Task { @MainActor in
                                await Task.yield()
                                if dragging { cancelDrag() }
                            }
                        }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active && dragging { cancelDrag() }
                    }
                }
                .task {
                    // Commit the pressed pose before changing the layout animation's target.
                    do { try await Task.sleep(for: .milliseconds(35)) } catch { return }
                    withAnimation(reduceMotion ? .linear(duration: 0.15) : .snappy(duration: 0.32, extraBounce: 0), completionCriteria: .removed) {
                        openProgress = 1
                        pressAmount = 0
                    } completion: { ready = true }
                    if !reduceMotion {
                        do { try await Task.sleep(for: .milliseconds(140)) } catch { return }
                    }
                    withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.16)) {
                        detailVisible = true
                    }
                }
            }.ignoresSafeArea()
        }
        .contentShape(Rectangle())
    }

    private func edgeReturn(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($touchingEdge) { value, active, _ in
                if value.startLocation.x <= 24 { active = true }
            }
            .onChanged { value in
                guard ready, !closing, value.startLocation.x <= 24 else { return }
                if !dragging {
                    guard value.translation.width > 0,
                          value.translation.width > abs(value.translation.height) * 1.3 else { return }
                    dragging = true
                }
                // No implicit animation while the finger controls the card.
                dragProgress = min(0.95, max(0, value.translation.width / (width * 0.85)))
            }
            .onEnded { value in
                guard dragging else { return }
                let projected = value.predictedEndTranslation.width / (width * 0.85)
                if dragProgress > 0.35 || (dragProgress > 0.08 && projected > 0.55) {
                    dragging = false
                    close()
                } else { cancelDrag() }
            }
    }

    private func cancelDrag() {
        dragging = false
        withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.8)) {
            dragProgress = 0
        }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        if scrollY > 1 {
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 0.2), completionCriteria: .removed) {
                scroll.scrollTo(edge: .top)
            } completion: { collapse() }
        } else { collapse() }
    }

    private func collapse() {
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.1)) {
            detailVisible = false
        }
        withAnimation(reduceMotion ? .linear(duration: 0.15) : .snappy(duration: 0.32, extraBounce: 0), completionCriteria: .removed) {
            openProgress = 0
        } completion: { onClose() }
    }
}

/// Supplies an interpolated progress to the card's layout on every animation frame.
/// Reading @State directly in body would only produce the start and end dimensions.
private struct RunwayAnimationPhase<Content: View>: View, Animatable {
    var openProgress: CGFloat
    var pressAmount: CGFloat
    var dragProgress: CGFloat
    let content: (CGFloat, CGFloat, CGFloat) -> Content

    init(openProgress: CGFloat, pressAmount: CGFloat, dragProgress: CGFloat, @ViewBuilder content: @escaping (CGFloat, CGFloat, CGFloat) -> Content) {
        self.openProgress = openProgress
        self.pressAmount = pressAmount
        self.dragProgress = dragProgress
        self.content = content
    }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(openProgress, pressAmount), dragProgress) }
        set {
            openProgress = newValue.first.first
            pressAmount = newValue.first.second
            dragProgress = newValue.second
        }
    }

    var body: some View { content(openProgress, pressAmount, dragProgress) }
}

/// Native button tracking keeps the pressed pose for as long as the finger is down,
/// and restores it automatically when scrolling cancels the tap.
struct RunwayCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 28))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.983 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

/// A small forward and upward arc is folded into the card's single expansion.
/// Both ends land exactly on the pressed card and the full-screen surface.
private struct RunwayCardLift: GeometryEffect {
    var progress: CGFloat
    var pressAmount: CGFloat
    let reduceMotion: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, pressAmount) }
        set { progress = newValue.first; pressAmount = newValue.second }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amount = min(1, max(0, progress))
        let press = reduceMotion ? 0 : min(1, max(0, pressAmount))
        let arc = reduceMotion ? 0 : sin(.pi * amount)
        let scale = 1 - 0.017 * press + 0.02 * arc
        let vertical = 2 * press - 8 * arc
        let transform = CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: (1 - scale) * size.width / 2,
            ty: (1 - scale) * size.height / 2 + vertical
        )
        return ProjectionTransform(transform)
    }
}
