import Foundation
import PackagePlugin

@main
struct OpenAPISanitizerCommandPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let tool = try context.tool(named: "openapi-sanitizer")
    let packageDirectory = context.package.directoryURL
    let resolvedArguments = try resolveArguments(
      arguments,
      packageDirectory: packageDirectory
    )
    try runTool(
      at: tool.url,
      arguments: resolvedArguments,
      currentDirectoryURL: packageDirectory
    )
  }
}

private func resolveArguments(
  _ arguments: [String],
  packageDirectory: URL
) throws -> [String] {
  var positionalArgumentCount = 0
  var resolvedArguments: [String] = []
  var iterator = arguments.makeIterator()

  while let argument = iterator.next() {
    resolvedArguments.append(argument)

    if argument == "--config" {
      guard let path = iterator.next() else {
        throw OpenAPISanitizerCommandPluginError.invalidArguments
      }
      resolvedArguments.append(resolvePath(path, relativeTo: packageDirectory).path)
    } else if !argument.hasPrefix("-") {
      positionalArgumentCount += 1
      resolvedArguments[resolvedArguments.count - 1] = resolvePath(
        argument,
        relativeTo: packageDirectory
      ).path
    }
  }

  guard positionalArgumentCount > 0, positionalArgumentCount <= 2 else {
    throw OpenAPISanitizerCommandPluginError.invalidArguments
  }

  if positionalArgumentCount == 1 && !resolvedArguments.contains("--in-place") {
    resolvedArguments.insert("--in-place", at: 0)
  }

  return resolvedArguments
}

private func resolvePath(_ path: String, relativeTo packageDirectory: URL) -> URL {
  let fileURL = URL(fileURLWithPath: path)

  if fileURL.path().hasPrefix("/") {
    return fileURL.standardizedFileURL
  }

  return packageDirectory.appendingPathComponent(path).standardizedFileURL
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
        swift package --allow-writing-to-package-directory \
          sanitize-openapi [options] --in-place input.json
        swift package --allow-writing-to-package-directory \
          sanitize-openapi [options] input.json output.json
      """
    case .toolFailed(let status):
      "openapi-sanitizer failed with exit status \(status)."
    }
  }
}
