import AppKit
import SwiftUI

/// Observes the actual viewport, so mouse, trackpad, keyboard and tree navigation agree.
/// AppKit bridges scroll geometry on macOS 14, before SwiftUI's scroll-geometry APIs.
@MainActor @Observable
final class TaleScrollPosition {
    private(set) var progress: CGFloat = 0
    private(set) var canScroll = false
    @ObservationIgnored private var savedOffset: CGFloat = 0
    @ObservationIgnored weak var scrollView: NSScrollView?

    func saveOffset() {
        guard let scrollView, let document = scrollView.documentView else { return }
        let viewport = scrollView.contentView.bounds
        savedOffset = max(0, document.isFlipped ? viewport.minY - document.bounds.minY : document.bounds.maxY - viewport.maxY)
    }

    func restoreOffset() {
        guard let scrollView, let document = scrollView.documentView else { return }
        let distance = max(0, document.bounds.height - scrollView.contentView.bounds.height)
        scroll(to: distance > 0 ? savedOffset / distance : 0)
    }

    func refresh() {
        guard let scrollView, let document = scrollView.documentView else { return }
        let viewport = scrollView.contentView.bounds
        let distance = max(0, document.bounds.height - viewport.height)
        canScroll = distance > 1
        let offset = document.isFlipped ? viewport.minY - document.bounds.minY : document.bounds.maxY - viewport.maxY
        progress = canScroll ? min(1, max(0, offset / distance)) : 0
    }

    func scroll(to fraction: CGFloat) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let distance = max(0, document.bounds.height - clip.bounds.height)
        let fraction = min(1, max(0, fraction))
        let y = document.bounds.minY + (document.isFlipped ? fraction : 1 - fraction) * distance
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: y))
        scrollView.reflectScrolledClipView(clip)
        refresh()
    }
}

struct TaleScrollObserver: NSViewRepresentable {
    let position: TaleScrollPosition

    func makeNSView(context: Context) -> ObserverView { ObserverView(position: position) }
    func updateNSView(_ view: ObserverView, context: Context) { view.scheduleRefresh() }
    static func dismantleNSView(_ view: ObserverView, coordinator: ()) { view.disconnect() }

    final class ObserverView: NSView {
        let position: TaleScrollPosition
        private weak var observedScrollView: NSScrollView?
        private var refreshScheduled = false

        init(position: TaleScrollPosition) {
            self.position = position
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { disconnect() }
            else { scheduleRefresh() }
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            scheduleRefresh()
        }

        func disconnect() {
            NotificationCenter.default.removeObserver(self)
            if position.scrollView === observedScrollView { position.scrollView = nil }
            observedScrollView = nil
        }

        // Notifications can arrive during a SwiftUI layout pass. Coalesce them and
        // publish on the next run-loop turn, never while SwiftUI is updating a view.
        @objc func scheduleRefresh() {
            guard !refreshScheduled else { return }
            refreshScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshScheduled = false
                guard self.window != nil, let scrollView = self.enclosingScrollView else { return }
                // Enforce this on the native view too: SwiftUI's hidden indicators
                // can still leave a scroller visible with macOS's Always setting.
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                if self.observedScrollView !== scrollView {
                    self.disconnect()
                    self.observedScrollView = scrollView
                    self.position.scrollView = scrollView
                    scrollView.contentView.postsBoundsChangedNotifications = true
                    scrollView.documentView?.postsFrameChangedNotifications = true
                    NotificationCenter.default.addObserver(self, selector: #selector(self.scheduleRefresh),
                                                           name: NSView.boundsDidChangeNotification,
                                                           object: scrollView.contentView)
                    if let document = scrollView.documentView {
                        NotificationCenter.default.addObserver(self, selector: #selector(self.scheduleRefresh),
                                                               name: NSView.frameDidChangeNotification, object: document)
                    }
                    self.position.restoreOffset()
                }
                self.position.refresh()
            }
        }
    }
}
