import Foundation
import PackagePlugin

@main
struct OpenAPISanitizerPlugin: BuildToolPlugin {
  func createBuildCommands(
    context: PluginContext,
    target: Target
  ) async throws -> [Command] {
    let tool = try context.tool(named: "OpenAPISanitizerCLI")
    let inputFiles = discoverInputFiles(in: target.directoryURL)

    return inputFiles.map {
      buildCommand(
        for: $0,
        in: context.pluginWorkDirectoryURL,
        executable: tool.url
      )
    }
  }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension OpenAPISanitizerPlugin: XcodeBuildToolPlugin {
  func createBuildCommands(
    context: XcodePluginContext,
    target: XcodeTarget
  ) throws -> [Command] {
    let tool = try context.tool(named: "OpenAPISanitizerCLI")
    let inputFiles = target.inputFiles.map(\.url).filter(isSupportedInputFile)

    return inputFiles.map {
      buildCommand(
        for: $0,
        in: context.pluginWorkDirectoryURL,
        executable: tool.url
      )
    }
  }
}
#endif

private func discoverInputFiles(in directory: URL) -> [URL] {
  guard let enumerator = FileManager.default.enumerator(
    at: directory,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
  ) else {
    return []
  }

  return enumerator.compactMap { entry in
    guard let fileURL = entry as? URL else {
      return nil
    }

    return isSupportedInputFile(fileURL) ? fileURL : nil
  }
}

private func isSupportedInputFile(_ fileURL: URL) -> Bool {
  let fileName = fileURL.lastPathComponent
  return fileName == "openapi.json.nullfix" || fileName.hasSuffix(".openapi.json.nullfix")
}

private func buildCommand(
  for inputFile: URL,
  in outputDirectory: URL,
  executable: URL
) -> Command {
  let outputName = generatedOpenAPIFileName(for: inputFile)
  let outputFile = outputDirectory.appendingPathComponent(outputName)

  return .buildCommand(
    displayName: "Generating \(outputName) from \(inputFile.lastPathComponent)",
    executable: executable,
    arguments: [inputFile.path(), outputFile.path()],
    inputFiles: [inputFile],
    outputFiles: [outputFile]
  )
}

private func generatedOpenAPIFileName(for inputFile: URL) -> String {
  String(inputFile.lastPathComponent.dropLast(".nullfix".count))
}
