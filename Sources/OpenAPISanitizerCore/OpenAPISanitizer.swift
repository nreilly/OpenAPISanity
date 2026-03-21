import Foundation

public struct OpenAPISanitizerOptions: Sendable {
  public let pruneOrphanRequiredProperties: Bool

  public init(pruneOrphanRequiredProperties: Bool = false) {
    self.pruneOrphanRequiredProperties = pruneOrphanRequiredProperties
  }
}

public struct OpenAPISanitizerReport: Sendable {
  public let data: Data
  public let modifications: [String]

  init(data: Data, modifications: [String]) {
    self.data = data
    self.modifications = modifications
  }
}

public struct OpenAPISanitizer {
  public init() {}

  public func rewriteNode(
    _ node: Any,
    options: OpenAPISanitizerOptions = OpenAPISanitizerOptions()
  ) -> Any {
    var modifications: [String] = []
    return rewrite(
      node,
      at: .root,
      options: options,
      modifications: &modifications
    ).node
  }

  public func rewriteObject(
    _ object: [String: Any],
    options: OpenAPISanitizerOptions = OpenAPISanitizerOptions()
  ) -> [String: Any] {
    guard let rewritten = rewriteNode(object, options: options) as? [String: Any] else {
      return object
    }

    return rewritten
  }

  public func isNullSchema(_ node: Any) -> Bool {
    guard let object = node as? [String: Any] else {
      return false
    }

    return object.count == 1 && (object["type"] as? String) == "null"
  }

  public func rewrite(
    data: Data,
    options: OpenAPISanitizerOptions = OpenAPISanitizerOptions()
  ) throws -> Data {
    try rewriteWithReport(data: data, options: options).data
  }

  public func rewriteWithReport(
    data: Data,
    options: OpenAPISanitizerOptions = OpenAPISanitizerOptions()
  ) throws -> OpenAPISanitizerReport {
    let json = try JSONSerialization.jsonObject(with: data)
    var modifications: [String] = []
    let rewritten = rewrite(
      json,
      at: .root,
      options: options,
      modifications: &modifications
    ).node
    let rewrittenData = try JSONSerialization.data(
      withJSONObject: rewritten,
      options: [.prettyPrinted, .sortedKeys]
    )
    return OpenAPISanitizerReport(data: rewrittenData, modifications: modifications)
  }

  private func rewrite(
    _ node: Any,
    at path: JSONPath,
    options: OpenAPISanitizerOptions,
    modifications: inout [String]
  ) -> RewriteResult {
    switch node {
    case let object as [String: Any]:
      return rewriteObjectNode(
        object,
        at: path,
        options: options,
        modifications: &modifications
      )
    case let array as [Any]:
      let rewrittenArray = array.enumerated().map { index, item in
        rewrite(
          item,
          at: path.appending(index: index),
          options: options,
          modifications: &modifications
        ).node
      }
      return RewriteResult(node: rewrittenArray, adjustedNullableSchema: false)
    default:
      return RewriteResult(node: node, adjustedNullableSchema: false)
    }
  }

  private func rewriteObjectNode(
    _ object: [String: Any],
    at path: JSONPath,
    options: OpenAPISanitizerOptions,
    modifications: inout [String]
  ) -> RewriteResult {
    var rewrittenObject: [String: Any] = [:]
    var adjustedPropertyNames = Set<String>()
    var propertyNames: Set<String>?

    for (key, value) in object {
      if key == "properties", let properties = value as? [String: Any] {
        let rewrittenProperties = rewriteProperties(
          properties,
          at: path.appending(key: "properties"),
          options: options,
          modifications: &modifications
        )
        rewrittenObject[key] = rewrittenProperties.properties
        adjustedPropertyNames = rewrittenProperties.adjustedPropertyNames
        propertyNames = Set(rewrittenProperties.properties.keys)
        continue
      }

      rewrittenObject[key] = rewrite(
        value,
        at: path.appending(key: key),
        options: options,
        modifications: &modifications
      ).node
    }

    if let required = rewrittenObject["required"] as? [String] {
      rewrittenObject["required"] = rewriteRequired(
        required,
        at: path,
        adjustedPropertyNames: adjustedPropertyNames,
        propertyNames: propertyNames,
        options: options,
        modifications: &modifications
      )
    }

    for keyword in ["oneOf", "anyOf"] {
      if let rewritten = rewriteUnion(
        in: rewrittenObject,
        keyword: keyword,
        at: path,
        modifications: &modifications
      ) {
        return rewritten
      }
    }

    return RewriteResult(node: rewrittenObject, adjustedNullableSchema: false)
  }

  private func rewriteRequired(
    _ required: [String],
    at objectPath: JSONPath,
    adjustedPropertyNames: Set<String>,
    propertyNames: Set<String>?,
    options: OpenAPISanitizerOptions,
    modifications: inout [String]
  ) -> [String] {
    let requiredPath = objectPath.appending(key: "required")
    var rewrittenRequired: [String] = []

    for propertyName in required {
      if adjustedPropertyNames.contains(propertyName) {
        modifications.append(
          "Removed required entry '\(propertyName)' from \(requiredPath) because " +
          "\(objectPath.appending(key: "properties").appending(key: propertyName)) " +
          "accepted null"
        )
        continue
      }

      if options.pruneOrphanRequiredProperties,
        let propertyNames,
        !propertyNames.contains(propertyName)
      {
        modifications.append(
          "Removed orphan required entry '\(propertyName)' from \(requiredPath) because " +
          "\(objectPath.appending(key: "properties").appending(key: propertyName)) " +
          "is missing"
        )
        continue
      }

      rewrittenRequired.append(propertyName)
    }

    return rewrittenRequired
  }

  private func mergeCollapsedBranch(
    branch: Any,
    into object: [String: Any]
  ) -> [String: Any] {
    guard let branchObject = branch as? [String: Any] else {
      return object
    }

    var merged = branchObject

    for (key, value) in object {
      merged[key] = value
    }

    return merged
  }

  private func rewriteProperties(
    _ properties: [String: Any],
    at path: JSONPath,
    options: OpenAPISanitizerOptions,
    modifications: inout [String]
  ) -> RewrittenProperties {
    var rewrittenProperties: [String: Any] = [:]
    var adjustedPropertyNames = Set<String>()

    for (propertyName, propertyValue) in properties {
      let rewrittenProperty = rewrite(
        propertyValue,
        at: path.appending(key: propertyName),
        options: options,
        modifications: &modifications
      )
      rewrittenProperties[propertyName] = rewrittenProperty.node

      if rewrittenProperty.adjustedNullableSchema {
        adjustedPropertyNames.insert(propertyName)
      }
    }

    return RewrittenProperties(
      properties: rewrittenProperties,
      adjustedPropertyNames: adjustedPropertyNames
    )
  }

  private func rewriteUnion(
    in object: [String: Any],
    keyword: String,
    at path: JSONPath,
    modifications: inout [String]
  ) -> RewriteResult? {
    guard let branches = object[keyword] as? [Any] else {
      return nil
    }

    let nonNullBranches = branches.filter { !isNullSchema($0) }
    let removedNullBranchCount = branches.count - nonNullBranches.count

    guard removedNullBranchCount > 0 else {
      return nil
    }

    guard !nonNullBranches.isEmpty else {
      return nil
    }

    let unionPath = path.appending(key: keyword)
    modifications.append(
      "Removed null branch(es) from \(unionPath) (count: \(removedNullBranchCount))"
    )

    switch nonNullBranches.count {
    case 1:
      var rewrittenObject = object
      rewrittenObject.removeValue(forKey: keyword)
      let merged = mergeCollapsedBranch(
        branch: nonNullBranches[0],
        into: rewrittenObject
      )
      modifications.append(
        "Collapsed \(keyword) at \(path) after removing null branch(es)"
      )
      return RewriteResult(node: merged, adjustedNullableSchema: true)
    default:
      var rewrittenObject = object
      rewrittenObject[keyword] = nonNullBranches
      return RewriteResult(node: rewrittenObject, adjustedNullableSchema: true)
    }
  }
}

private struct RewriteResult {
  let node: Any
  let adjustedNullableSchema: Bool
}

private struct RewrittenProperties {
  let properties: [String: Any]
  let adjustedPropertyNames: Set<String>
}

private struct JSONPath: CustomStringConvertible {
  static let root = JSONPath(components: [])

  private let components: [JSONPathComponent]

  fileprivate init(components: [JSONPathComponent]) {
    self.components = components
  }

  func appending(key: String) -> JSONPath {
    JSONPath(components: components + [.key(key)])
  }

  func appending(index: Int) -> JSONPath {
    JSONPath(components: components + [.index(index)])
  }

  var description: String {
    components.reduce("$") { partialResult, component in
      partialResult + component.description
    }
  }
}

private enum JSONPathComponent: CustomStringConvertible {
  case key(String)
  case index(Int)

  var description: String {
    switch self {
    case .key(let key):
      if key.unicodeScalars.allSatisfy(isSimpleIdentifierScalar(_:)) {
        return ".\(key)"
      }

      let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")
      return "['\(escapedKey)']"
    case .index(let index):
      return "[\(index)]"
    }
  }

  private func isSimpleIdentifierScalar(_ scalar: UnicodeScalar) -> Bool {
    switch scalar {
    case "a"..."z", "A"..."Z", "0"..."9", "_":
      return true
    default:
      return false
    }
  }
}

public enum OpenAPISanitizerCommand {
  public static func run(
    arguments: [String],
    log: (String) -> Void = { print($0) }
  ) throws {
    let configuration = try Configuration(arguments: arguments)
    let inputURL = configuration.inputURL
    let outputURL = configuration.outputURL
    let data = try Data(contentsOf: inputURL)
    let report = try OpenAPISanitizer().rewriteWithReport(
      data: data,
      options: configuration.options
    )
    try write(report.data, to: outputURL)

    if !configuration.isQuiet {
      for modification in report.modifications {
        log(modification)
      }
    }
  }

  private static func write(_ data: Data, to outputURL: URL) throws {
    let temporaryURL = outputURL
      .deletingLastPathComponent()
      .appendingPathComponent(".\(UUID().uuidString).tmp")

    try data.write(to: temporaryURL, options: .atomic)

    if FileManager.default.fileExists(atPath: outputURL.path()) {
      _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporaryURL)
    } else {
      try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
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
      var pruneOrphanRequiredProperties = false
      var positionalArguments: [String] = []

      for argument in arguments.dropFirst() {
        switch argument {
        case "--in-place":
          isInPlace = true
        case "--prune-orphan-required":
          pruneOrphanRequiredProperties = true
        case "--quiet":
          isQuiet = true
        default:
          guard !argument.hasPrefix("-") else {
            throw OpenAPISanitizerCommandError.invalidArguments
          }

          positionalArguments.append(argument)
        }
      }

      options = OpenAPISanitizerOptions(
        pruneOrphanRequiredProperties: pruneOrphanRequiredProperties
      )
      self.isQuiet = isQuiet

      if isInPlace {
        guard positionalArguments.count == 1 else {
          throw OpenAPISanitizerCommandError.invalidArguments
        }

        inputURL = URL(fileURLWithPath: positionalArguments[0])
        outputURL = inputURL
        return
      }

      guard positionalArguments.count == 2 else {
        throw OpenAPISanitizerCommandError.invalidArguments
      }

      inputURL = URL(fileURLWithPath: positionalArguments[0])
      outputURL = URL(fileURLWithPath: positionalArguments[1])
    }
  }
}

public enum OpenAPISanitizerCommandError: LocalizedError {
  case invalidArguments

  public var errorDescription: String? {
    switch self {
    case .invalidArguments:
      """
      Usage:
        openapi-sanitizer [--quiet] [--prune-orphan-required] --in-place input.json
        openapi-sanitizer [--quiet] [--prune-orphan-required] input.json output.json
      """
    }
  }
}
