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
  let positionalArguments = arguments.filter { !$0.hasPrefix("-") }

  guard !positionalArguments.isEmpty, positionalArguments.count <= 2 else {
    throw OpenAPISanitizerCommandPluginError.invalidArguments
  }

  var resolvedArguments = arguments.map { argument in
    if argument.hasPrefix("-") {
      return argument
    }

    return resolvePath(argument, relativeTo: packageDirectory).path()
  }

  if positionalArguments.count == 1 && !resolvedArguments.contains("--in-place") {
    resolvedArguments.insert("--in-place", at: 0)
  }

  return resolvedArguments
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
        swift package --allow-writing-to-package-directory sanitize-openapi [--quiet] [--prune-orphan-required] --in-place path/to/openapi.json
        swift package --allow-writing-to-package-directory sanitize-openapi [--quiet] [--prune-orphan-required] path/to/openapi.json
        swift package --allow-writing-to-package-directory sanitize-openapi [--quiet] [--prune-orphan-required] input.json output.json
      """
    case .toolFailed(let status):
      "openapi-sanitizer failed with exit status \(status)."
    }
  }
}
