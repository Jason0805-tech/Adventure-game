import Foundation
import Darwin

let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let macOSURL = executableURL.deletingLastPathComponent()
let resourcesURL = macOSURL.deletingLastPathComponent().appendingPathComponent("Resources", isDirectory: true)
let engineURL = macOSURL.appendingPathComponent("GodotRuntime")
let arguments = [engineURL.path, "--path", resourcesURL.path] + CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
guard FileManager.default.changeCurrentDirectoryPath(resourcesURL.path) else {
    FileHandle.standardError.write(Data("Forest Wanderer resources could not be opened.\n".utf8))
    exit(1)
}
// Replace the launcher process so Finder's application lifecycle follows
// the game itself. Always choose bundled resources, independent of the cwd.
var cArguments = arguments.map { argument in argument.withCString { strdup($0) } }
cArguments.append(nil)
_ = cArguments.withUnsafeMutableBufferPointer { buffer in
    engineURL.path.withCString { enginePath in execv(enginePath, buffer.baseAddress!) }
}
let message = String(cString: strerror(errno))
FileHandle.standardError.write(Data("Forest Wanderer could not start: \(message)\n".utf8))
exit(1)
