import Foundation
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments
let directory = URL(fileURLWithPath: args[1])
let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys:nil).filter {$0.lastPathComponent.hasPrefix("motion-") && $0.pathExtension == "png"}.sorted {$0.lastPathComponent < $1.lastPathComponent}
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath:args[2]) as CFURL, UTType.gif.identifier as CFString,files.count,nil)!
CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for file in files {
 let source = CGImageSourceCreateWithURL(file as CFURL,nil)!
 let frame = CGImageSourceCreateImageAtIndex(source,0,nil)!
 CGImageDestinationAddImage(destination,frame,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.083333,kCGImagePropertyGIFUnclampedDelayTime:0.083333]] as CFDictionary)
}
if !CGImageDestinationFinalize(destination) { fatalError("GIF write failed") }
print("Animated game capture:",files.count,"frames")
