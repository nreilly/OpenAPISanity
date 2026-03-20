import Foundation
import OpenAPISanitizerCore

do {
  try OpenAPISanitizerCommand.run(arguments: CommandLine.arguments)
} catch {
  let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}
