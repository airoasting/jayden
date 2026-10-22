// 앱 아이콘 PNG를 그린다. 사용: swift make-icon.swift <출력.png> <크기px>
import AppKit

let args = CommandLine.arguments
let out = args[1]
let size = CGFloat(Double(args[2]) ?? 1024)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
NSColor(white: 0.1, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2).fill()

// 남은 시간을 뜻하는 빨간 호
let center = NSPoint(x: size / 2, y: size / 2)
let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: size * 0.3, startAngle: 90, endAngle: -180, clockwise: true)
arc.lineWidth = size * 0.05
arc.lineCapStyle = .round
NSColor.systemRed.setStroke()
arc.stroke()

let text = "3:00" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.16, weight: .bold),
    .foregroundColor: NSColor.white,
]
let ts = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: center.x - ts.width / 2, y: center.y - ts.height / 2), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
