import Foundation
import OpenAPISanitizerCore

enum OpenAPISanitizerCLI {
  static func run(arguments: [String]) throws {
    guard arguments.count == 3 else {
      throw CLIError.invalidArguments
    }

    let inputURL = URL(fileURLWithPath: arguments[1])
    let outputURL = URL(fileURLWithPath: arguments[2])
    let data = try Data(contentsOf: inputURL)
    let sanitizer = OpenAPISanitizer()
    let rewritten = try sanitizer.rewrite(data: data)
    try rewritten.write(to: outputURL)
  }
}

enum CLIError: LocalizedError {
  case invalidArguments

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      "Usage: openapi-sanitizer input.json output.json"
    }
  }
}

do {
  try OpenAPISanitizerCLI.run(arguments: CommandLine.arguments)
} catch {
  let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}
