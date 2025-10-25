#!/usr/bin/env swift

import AppKit
import Foundation

// Icon sizes needed for macOS app
let iconSizes: [(size: CGFloat, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

func generateIcon(size: CGFloat, scale: Int, filename: String, outputDir: String) {
    let actualSize = size * CGFloat(scale)
    let image = NSImage(size: NSSize(width: actualSize, height: actualSize))

    image.lockFocus()

    // Background gradient (blue to purple)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 1.0)
    ])

    let bounds = NSRect(origin: .zero, size: NSSize(width: actualSize, height: actualSize))

    // Draw rounded square background
    let cornerRadius = actualSize * 0.225 // macOS icon corner radius ratio
    let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient?.draw(in: path, angle: 135)

    // Draw microphone symbol from SF Symbols
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: actualSize * 0.5, weight: .medium)
    if let micSymbol = NSImage(systemSymbolName: "microphone.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {

        // Center the symbol
        let symbolSize = micSymbol.size
        let x = (actualSize - symbolSize.width) / 2
        let y = (actualSize - symbolSize.height) / 2
        let symbolRect = NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        // Draw white symbol
        NSColor.white.set()
        micSymbol.draw(in: symbolRect)
    }

    image.unlockFocus()

    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {

        let outputPath = "\(outputDir)/\(filename)"
        let url = URL(fileURLWithPath: outputPath)

        do {
            try pngData.write(to: url)
            print("✓ Generated: \(filename)")
        } catch {
            print("✗ Failed to write \(filename): \(error)")
        }
    }
}

// Main execution
print("🎨 Generating BetterVoice placeholder icons...")

let currentDir = FileManager.default.currentDirectoryPath
let outputDir = "\(currentDir)/BetterVoice/BetterVoice/Assets.xcassets/AppIcon.appiconset"

// Check if output directory exists
if !FileManager.default.fileExists(atPath: outputDir) {
    print("✗ Error: AppIcon.appiconset directory not found at: \(outputDir)")
    exit(1)
}

// Generate all icons
for iconSpec in iconSizes {
    generateIcon(size: iconSpec.size, scale: iconSpec.scale, filename: iconSpec.filename, outputDir: outputDir)
}

print("✅ All placeholder icons generated successfully!")
print("📁 Location: \(outputDir)")
print("\n💡 To use: Open Xcode and the icons should appear in Assets.xcassets/AppIcon")
