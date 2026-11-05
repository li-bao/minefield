import Cocoa

// 建立 1024x1024 專業原生 macOS 圖示
let size = NSSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context
let cg = context.cgContext

// 1. 底層透明清除
cg.clear(CGRect(origin: .zero, size: size))

// 2. macOS 圓角外框 (標準 Squircle 邊界: 80, 80, 864, 864, 圓角 196)
let rect = CGRect(x: 80, y: 80, width: 864, height: 864)
let path = NSBezierPath(roundedRect: rect, xRadius: 196, yRadius: 196)

// 繪製陰影
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
NSColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1.0).setFill()
path.fill()
cg.restoreGState()

// 3. 背景深邃漸層 (深黑至夜空靛藍)
cg.saveGState()
path.addClip()
let bgColors = [
    CGColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
    CGColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
] as CFArray
let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0])!
cg.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 944), end: CGPoint(x: 512, y: 80), options: [])

// 4. 背景精緻網格紋理 (掃雷格子意象)
cg.setStrokeColor(CGColor(red: 0.20, green: 0.25, blue: 0.35, alpha: 0.20))
cg.setLineWidth(2.0)
let step: CGFloat = 864.0 / 8.0
for i in 1..<8 {
    let x = 80 + CGFloat(i) * step
    cg.move(to: CGPoint(x: x, y: 80))
    cg.addLine(to: CGPoint(x: x, y: 944))
    cg.strokePath()

    let y = 80 + CGFloat(i) * step
    cg.move(to: CGPoint(x: 80, y: y))
    cg.addLine(to: CGPoint(x: 944, y: y))
    cg.strokePath()
}

// 5. 幾何立體地雷主體
let center = CGPoint(x: 512, y: 512)

// A. 8 方向現代幾何觸角 (Spikes)
let spikeCount = 8
let spikeLength: CGFloat = 260
let spikeBaseWidth: CGFloat = 36

for i in 0..<spikeCount {
    let angle = CGFloat(i) * (2 * .pi / CGFloat(spikeCount)) + (.pi / 8)
    cg.saveGState()
    cg.translateBy(x: center.x, y: center.y)
    cg.rotate(by: angle)

    // 觸角路徑
    let spikePath = CGMutablePath()
    spikePath.move(to: CGPoint(x: -spikeBaseWidth / 2, y: 140))
    spikePath.addLine(to: CGPoint(x: -spikeBaseWidth / 4, y: spikeLength - 30))
    // 圓端觸頭
    spikePath.addArc(center: CGPoint(x: 0, y: spikeLength), radius: 18, startAngle: .pi, endAngle: 0, clockwise: false)
    spikePath.addLine(to: CGPoint(x: spikeBaseWidth / 4, y: spikeLength - 30))
    spikePath.addLine(to: CGPoint(x: spikeBaseWidth / 2, y: 140))
    spikePath.closeSubpath()

    // 觸角微光漸層 (青綠色至神秘深紫)
    let spikeColors = [
        CGColor(red: 0.58, green: 0.32, blue: 0.95, alpha: 0.9), // 紫色
        CGColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 0.9)  // 青綠
    ] as CFArray
    let spikeGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: spikeColors, locations: [0.0, 1.0])!

    cg.addPath(spikePath)
    cg.clip()
    cg.drawLinearGradient(spikeGrad, start: CGPoint(x: 0, y: 140), end: CGPoint(x: 0, y: spikeLength + 18), options: [])
    cg.restoreGState()
}

// B. 地雷核心球體 (幾何球核與邊框)
let coreRadius: CGFloat = 168
let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)

// 球體外發光
cg.saveGState()
cg.setShadow(offset: .zero, blur: 36, color: CGColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 0.65))
cg.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0))
cg.fillEllipse(in: coreRect)
cg.restoreGState()

// 球體表面金屬與科技光暈
cg.saveGState()
cg.addEllipse(in: coreRect)
cg.clip()

let coreColors = [
    CGColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 1.0),
    CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1.0)
] as CFArray
let coreGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: coreColors, locations: [0.0, 1.0])!
cg.drawRadialGradient(coreGrad, startCenter: CGPoint(x: 460, y: 570), startRadius: 10, endCenter: center, endRadius: coreRadius, options: [.drawsAfterEndLocation])

// 球面高光弧線
cg.setStrokeColor(CGColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 0.8))
cg.setLineWidth(6.0)
cg.addArc(center: center, radius: coreRadius - 12, startAngle: 0.2 * .pi, endAngle: 0.8 * .pi, clockwise: false)
cg.strokePath()

// 內部晶片核心菱形標誌 (象徵 AI / CSP 運算)
let diamondSize: CGFloat = 64
let diamondPath = CGMutablePath()
diamondPath.move(to: CGPoint(x: center.x, y: center.y + diamondSize))
diamondPath.addLine(to: CGPoint(x: center.x + diamondSize, y: center.y))
diamondPath.addLine(to: CGPoint(x: center.x, y: center.y - diamondSize))
diamondPath.addLine(to: CGPoint(x: center.x - diamondSize, y: center.y))
diamondPath.closeSubpath()

let diamondColors = [
    CGColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 1.0),
    CGColor(red: 0.58, green: 0.32, blue: 0.95, alpha: 1.0)
] as CFArray
let diamondGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: diamondColors, locations: [0.0, 1.0])!

cg.saveGState()
cg.setShadow(offset: .zero, blur: 20, color: CGColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 0.9))
cg.addPath(diamondPath)
cg.clip()
cg.drawLinearGradient(diamondGrad, start: CGPoint(x: center.x - diamondSize, y: center.y + diamondSize), end: CGPoint(x: center.x + diamondSize, y: center.y - diamondSize), options: [])
cg.restoreGState()

cg.restoreGState()

// 6. 外框內邊緣光暈 (Inner border highlight)
cg.saveGState()
path.lineWidth = 4.0
NSColor(red: 0.18, green: 0.83, blue: 0.75, alpha: 0.35).setStroke()
path.stroke()
cg.restoreGState()

cg.restoreGState()
NSGraphicsContext.restoreGraphicsState()

// 儲存 1024x1024 Master PNG
let pngData = rep.representation(using: .png, properties: [:])!
let outURL = URL(fileURLWithPath: "Resources/Icons/master_icon.png")
try! pngData.write(to: outURL)
print("✓ Master icon generated at \(outURL.path)")
