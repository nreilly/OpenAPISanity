import Foundation

/// The sanitised document and a description of each applied modification.
public struct OpenAPISanitizerReport: Sendable {
  /// The sanitised JSON data.
  public let data: Data

  /// Human-readable descriptions of applied transformations.
  public let modifications: [String]

  init(data: Data, modifications: [String]) {
    self.data = data
    self.modifications = modifications
  }
}
