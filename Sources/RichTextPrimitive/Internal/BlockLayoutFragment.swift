#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import CoreGraphics

final class BlockLayoutFragment: NSTextLayoutFragment {
    override func draw(at point: CGPoint, in context: CGContext) {
        drawBlockDecoration(at: point, in: context)
        super.draw(at: point, in: context)
    }

    private func drawBlockDecoration(at point: CGPoint, in context: CGContext) {
        guard let element = textElement as? BlockTextElement else { return }
        let frame = layoutFragmentFrame.offsetBy(dx: point.x, dy: point.y)

        context.saveGState()
        defer { context.restoreGState() }

        switch element.blockType {
        case .blockQuote:
            context.setFillColor(platformDecorationColor(red: 0.45, green: 0.49, blue: 0.54, alpha: 0.5))
            context.fill(CGRect(x: frame.minX, y: frame.minY, width: 3, height: frame.height))
        case .codeBlock:
            context.setFillColor(platformDecorationColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1))
            context.fill(frame.insetBy(dx: -6, dy: -4))
        case .list:
            context.setFillColor(platformDecorationColor(red: 0.45, green: 0.49, blue: 0.54, alpha: 0.25))
            context.fill(CGRect(x: frame.minX, y: frame.minY, width: 1, height: frame.height))
        case .paragraph, .heading, .table, .image, .divider, .embed:
            break
        }
    }

    private func platformDecorationColor(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat
    ) -> CGColor {
        #if canImport(AppKit)
        NSColor(red: red, green: green, blue: blue, alpha: alpha).cgColor
        #else
        UIColor(red: red, green: green, blue: blue, alpha: alpha).cgColor
        #endif
    }
}
