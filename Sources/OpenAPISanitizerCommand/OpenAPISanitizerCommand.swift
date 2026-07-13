import Foundation
import OpenAPISanitizerCore

package enum OpenAPISanitizerCommand {
  package static func run(
    arguments: [String],
    log: (String) -> Void = { print($0) }
  ) throws {
    let configuration = try Configuration(arguments: arguments)
    let data = try Data(contentsOf: configuration.inputURL)
    let report = try OpenAPISanitizer().rewriteWithReport(
      data: data,
      options: configuration.options
    )
    try write(report.data, to: configuration.outputURL)

    if !configuration.isQuiet {
      for modification in report.modifications {
        log(modification)
      }
    }
  }

  private static func write(_ data: Data, to outputURL: URL) throws {
    let fileManager = FileManager.default
    let outputDirectory = outputURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    if fileManager.fileExists(atPath: outputURL.path),
      try Data(contentsOf: outputURL) == data
    {
      return
    }

    let temporaryURL = outputDirectory
      .appendingPathComponent(".\(UUID().uuidString).tmp")
    try data.write(to: temporaryURL, options: .atomic)

    if fileManager.fileExists(atPath: outputURL.path) {
      _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryURL)
    } else {
      try fileManager.moveItem(at: temporaryURL, to: outputURL)
    }
  }
}

extension OpenAPISanitizerCommand {
  struct Configuration {
    let inputURL: URL
    let outputURL: URL
    let options: OpenAPISanitizerOptions
    let isQuiet: Bool

    init(arguments: [String]) throws {
      var isQuiet = false
      var isInPlace = false
      var makeNullablePropertiesOptional = false
      var pruneOrphanRequiredProperties = false
      var rewritePathParameterFormStyle = false
      var configurationURL: URL?
      var positionalArguments: [String] = []
      var iterator = arguments.dropFirst().makeIterator()

      while let argument = iterator.next() {
        switch argument {
        case "--config":
          guard let path = iterator.next() else {
            throw OpenAPISanitizerCommandError.invalidArguments
          }
          configurationURL = URL(fileURLWithPath: path)
        case "--in-place":
          isInPlace = true
        case "--make-nullable-properties-optional":
          makeNullablePropertiesOptional = true
        case "--prune-orphan-required":
          pruneOrphanRequiredProperties = true
        case "--rewrite-path-parameter-form-style":
          rewritePathParameterFormStyle = true
        case "--quiet":
          isQuiet = true
        default:
          guard !argument.hasPrefix("-") else {
            throw OpenAPISanitizerCommandError.invalidArguments
          }
          positionalArguments.append(argument)
        }
      }

      let fileOptions = try configurationURL.map { url in
        try JSONDecoder().decode(
          OpenAPISanitizerOptions.self,
          from: Data(contentsOf: url)
        )
      } ?? OpenAPISanitizerOptions()
      options = OpenAPISanitizerOptions(
        pruneOrphanRequiredProperties: pruneOrphanRequiredProperties
          || fileOptions.pruneOrphanRequiredProperties,
        makeNullablePropertiesOptional: makeNullablePropertiesOptional
          || fileOptions.makeNullablePropertiesOptional,
        rewritePathParameterFormStyle: rewritePathParameterFormStyle
          || fileOptions.rewritePathParameterFormStyle
      )
      self.isQuiet = isQuiet

      if isInPlace {
        guard positionalArguments.count == 1 else {
          throw OpenAPISanitizerCommandError.invalidArguments
        }
        inputURL = URL(fileURLWithPath: positionalArguments[0])
        outputURL = inputURL
      } else {
        guard positionalArguments.count == 2 else {
          throw OpenAPISanitizerCommandError.invalidArguments
        }
        inputURL = URL(fileURLWithPath: positionalArguments[0])
        outputURL = URL(fileURLWithPath: positionalArguments[1])
      }
    }
  }
}

package enum OpenAPISanitizerCommandError: LocalizedError {
  case invalidArguments

  package var errorDescription: String? {
    switch self {
    case .invalidArguments:
      """
      Usage:
        openapi-sanitizer [options] --in-place input.json
        openapi-sanitizer [options] input.json output.json

      Options:
        --config path/to/openapi-sanitizer-config.json
        --make-nullable-properties-optional
        --prune-orphan-required
        --rewrite-path-parameter-form-style
        --quiet
      """
    }
  }
}
