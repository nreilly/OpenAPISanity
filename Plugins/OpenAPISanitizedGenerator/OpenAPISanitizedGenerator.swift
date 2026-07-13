import Foundation
import PackagePlugin

@main
struct OpenAPISanitizedGenerator: BuildToolPlugin {
  func createBuildCommands(
    context: PluginContext,
    target: Target
  ) async throws -> [Command] {
    guard let swiftTarget = target as? SwiftSourceModuleTarget else {
      throw OpenAPISanitizedGeneratorError.incompatibleTarget(target.name)
    }

    return try makeBuildCommands(
      pluginWorkDirectory: context.pluginWorkDirectoryURL,
      inputFiles: swiftTarget.sourceFiles.map(\.url),
      sanitizerURL: context.tool(named: "openapi-sanitizer").url,
      generatorURL: context.tool(named: "swift-openapi-generator").url,
      targetName: target.name
    )
  }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension OpenAPISanitizedGenerator: XcodeBuildToolPlugin {
  func createBuildCommands(
    context: XcodePluginContext,
    target: XcodeTarget
  ) throws -> [Command] {
    try makeBuildCommands(
      pluginWorkDirectory: context.pluginWorkDirectoryURL,
      inputFiles: target.inputFiles.map(\.url),
      sanitizerURL: context.tool(named: "openapi-sanitizer").url,
      generatorURL: context.tool(named: "swift-openapi-generator").url,
      targetName: target.displayName
    )
  }
}
#endif

private func makeBuildCommands(
  pluginWorkDirectory: URL,
  inputFiles: [URL],
  sanitizerURL: URL,
  generatorURL: URL,
  targetName: String
) throws -> [Command] {
  let sourceURL = try requireSingleFile(
    named: "openapi-source.json",
    in: inputFiles,
    targetName: targetName
  )
  let generatorConfigurationURL = try requireSingleFile(
    namedOneOf: [
      "openapi-generator-config.yaml",
      "openapi-generator-config.yml",
    ],
    in: inputFiles,
    targetName: targetName
  )
  let sanitizerConfigurationURL = try optionalSingleFile(
    named: "openapi-sanitizer-config.json",
    in: inputFiles,
    targetName: targetName
  )
  let sanitizedURL = pluginWorkDirectory
    .appendingPathComponent("Sanitized", isDirectory: true)
    .appendingPathComponent("openapi.json")
  let generatedSourcesDirectory = pluginWorkDirectory
    .appendingPathComponent("GeneratedSources", isDirectory: true)
  let generatedSources = ["Types.swift", "Client.swift", "Server.swift"].map {
    generatedSourcesDirectory.appendingPathComponent($0)
  }

  var sanitizerArguments = ["--quiet"]
  var sanitizerInputs = [sourceURL]
  if let sanitizerConfigurationURL {
    sanitizerArguments += ["--config", sanitizerConfigurationURL.path]
    sanitizerInputs.append(sanitizerConfigurationURL)
  }
  sanitizerArguments += [sourceURL.path, sanitizedURL.path]

  return [
    .buildCommand(
      displayName: "Sanitising OpenAPI document for \(targetName)",
      executable: sanitizerURL,
      arguments: sanitizerArguments,
      inputFiles: sanitizerInputs,
      outputFiles: [sanitizedURL]
    ),
    .buildCommand(
      displayName: "Generating Swift OpenAPI sources for \(targetName)",
      executable: generatorURL,
      arguments: [
        "generate",
        sanitizedURL.path,
        "--config",
        generatorConfigurationURL.path,
        "--output-directory",
        generatedSourcesDirectory.path,
        "--plugin-source",
        "build",
      ],
      inputFiles: [sanitizedURL, generatorConfigurationURL],
      outputFiles: generatedSources
    ),
  ]
}

private func requireSingleFile(
  named name: String,
  in inputFiles: [URL],
  targetName: String
) throws -> URL {
  try requireSingleFile(
    namedOneOf: [name],
    in: inputFiles,
    targetName: targetName
  )
}

private func requireSingleFile(
  namedOneOf names: Set<String>,
  in inputFiles: [URL],
  targetName: String
) throws -> URL {
  let matches = inputFiles.filter { names.contains($0.lastPathComponent) }
  guard matches.count == 1, let match = matches.first else {
    throw OpenAPISanitizedGeneratorError.invalidFileCount(
      expectedNames: names.sorted(),
      actualCount: matches.count,
      targetName: targetName
    )
  }
  return match
}

private func optionalSingleFile(
  named name: String,
  in inputFiles: [URL],
  targetName: String
) throws -> URL? {
  let matches = inputFiles.filter { $0.lastPathComponent == name }
  guard matches.count <= 1 else {
    throw OpenAPISanitizedGeneratorError.invalidFileCount(
      expectedNames: [name],
      actualCount: matches.count,
      targetName: targetName
    )
  }
  return matches.first
}

private enum OpenAPISanitizedGeneratorError: Error, CustomStringConvertible {
  case incompatibleTarget(String)
  case invalidFileCount(
    expectedNames: [String],
    actualCount: Int,
    targetName: String
  )

  var description: String {
    switch self {
    case .incompatibleTarget(let targetName):
      "OpenAPISanitizedGenerator requires a Swift source target; got '\(targetName)'."
    case .invalidFileCount(let names, let count, let targetName):
      "Expected exactly one of \(names) in target '\(targetName)'; found \(count)."
    }
  }
}
