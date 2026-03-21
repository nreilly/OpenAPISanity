import Foundation
import PackagePlugin

@main
struct OpenAPISanitizerCommandPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let tool = try context.tool(named: "OpenAPISanitizerCommandTool")
    let resolvedArguments = try resolveArguments(arguments, packageDirectory: context.package.directoryURL)
    try runTool(at: tool.url, arguments: resolvedArguments, currentDirectoryURL: context.package.directoryURL)
  }
}

private func resolveArguments(
  _ arguments: [String],
  packageDirectory: URL
) throws -> [String] {
  if arguments.count == 1, let inputPath = arguments.first, !inputPath.hasPrefix("-") {
    let resolvedInput = resolvePath(inputPath, relativeTo: packageDirectory)
    return ["--in-place", resolvedInput.path()]
  }

  if arguments.count == 2, arguments.first == "--in-place", let inputPath = arguments.last {
    let resolvedInput = resolvePath(inputPath, relativeTo: packageDirectory)
    return ["--in-place", resolvedInput.path()]
  }

  if arguments.count == 2 {
    let inputURL = resolvePath(arguments[0], relativeTo: packageDirectory)
    let outputURL = resolvePath(arguments[1], relativeTo: packageDirectory)
    return [inputURL.path(), outputURL.path()]
  }

  throw OpenAPISanitizerCommandPluginError.invalidArguments
}

private func resolvePath(_ path: String, relativeTo packageDirectory: URL) -> URL {
  let fileURL = URL(fileURLWithPath: path)

  if fileURL.path().hasPrefix("/") {
    return fileURL.standardizedFileURL
  }

  return packageDirectory.appending(path: path).standardizedFileURL
}

private func runTool(
  at executableURL: URL,
  arguments: [String],
  currentDirectoryURL: URL
) throws {
  let process = Process()
  process.executableURL = executableURL
  process.arguments = arguments
  process.currentDirectoryURL = currentDirectoryURL
  try process.run()
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    throw OpenAPISanitizerCommandPluginError.toolFailed(status: process.terminationStatus)
  }
}

enum OpenAPISanitizerCommandPluginError: LocalizedError {
  case invalidArguments
  case toolFailed(status: Int32)

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      """
      Usage:
        swift package --allow-writing-to-package-directory sanitize-openapi --in-place path/to/openapi.json
        swift package --allow-writing-to-package-directory sanitize-openapi path/to/openapi.json
        swift package --allow-writing-to-package-directory sanitize-openapi input.json output.json
      """
    case .toolFailed(let status):
      "openapi-sanitizer failed with exit status \(status)."
    }
  }
}
