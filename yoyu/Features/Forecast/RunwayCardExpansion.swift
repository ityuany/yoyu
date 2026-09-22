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
    @State private var released = false
    @State private var dragProgress: CGFloat = 0
    @State private var dragging = false
    @GestureState private var touchingEdge = false
    @State private var expanded = false
    @State private var ready = false
    @State private var closing = false
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var scrollY: CGFloat = 0

    var body: some View {
        GeometryReader { safe in
            GeometryReader { canvas in
                let bounds = canvas.frame(in: .global)
                let start = source.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
                let openness = expanded ? 1 - dragProgress : 0
                let width = start.width + (canvas.size.width - start.width) * openness
                let height = start.height + (canvas.size.height - start.height) * openness
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.ultraThinMaterial)
                        .opacity(openness).ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 0) {
                            header()
                                .padding(.top, safe.safeAreaInsets.top * openness)
                            details()
                                .allowsHitTesting(ready && !closing && !dragging)
                                .padding(.bottom, safe.safeAreaInsets.bottom + 24)
                                .opacity(openness)
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
                    .clipShape(RoundedRectangle(cornerRadius: 28 * (1 - openness), style: .continuous))
                    .shadow(color: .black.opacity(0.15 * openness), radius: 24, y: 8)
                    .scaleEffect(released || reduceMotion ? 1 : 0.975)
                    .offset(x: start.minX * (1 - openness), y: start.minY * (1 - openness) + (released || reduceMotion ? 0 : 3))
                }
                .overlay(alignment: .topTrailing) {
                    Button { close() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary).frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .tint(.primary)
                    .padding(.top, safe.safeAreaInsets.top + 12).padding(.trailing, 16)
                    .opacity(ready && !closing ? 1 - dragProgress : 0)
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
                .task {
                    // The lifted surface begins in the same pressed pose as the button.
                    await Task.yield()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.65)) {
                        released = true
                    }
                    if !reduceMotion {
                        do { try await Task.sleep(for: .milliseconds(70)) } catch { return }
                    }
                    withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.58, dampingFraction: 0.82), completionCriteria: .removed) {
                        expanded = true
                    } completion: { ready = true }

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
        withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.48, dampingFraction: 0.9), completionCriteria: .removed) {
            expanded = false
        } completion: { onClose() }
    }
}

/// Native button tracking keeps the pressed pose for as long as the finger is down,
/// and restores it automatically when scrolling cancels the tap.
struct RunwayCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 28))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 3 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
