import Foundation

public struct OpenAPISanitizer {
  public init() {}

  public func rewriteNode(_ node: Any) -> Any {
    rewrite(node).node
  }

  public func rewriteObject(_ object: [String: Any]) -> [String: Any] {
    guard let rewritten = rewrite(object).node as? [String: Any] else {
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

  public func rewrite(data: Data) throws -> Data {
    let json = try JSONSerialization.jsonObject(with: data)
    let rewritten = rewriteNode(json)
    return try JSONSerialization.data(
      withJSONObject: rewritten,
      options: [.prettyPrinted, .sortedKeys]
    )
  }

  private func rewrite(_ node: Any) -> RewriteResult {
    switch node {
    case let object as [String: Any]:
      return rewriteObjectNode(object)
    case let array as [Any]:
      let rewrittenArray = array.map { rewrite($0).node }
      return RewriteResult(node: rewrittenArray, adjustedNullableSchema: false)
    default:
      return RewriteResult(node: node, adjustedNullableSchema: false)
    }
  }

  private func rewriteObjectNode(_ object: [String: Any]) -> RewriteResult {
    var rewrittenObject: [String: Any] = [:]
    var adjustedPropertyNames = Set<String>()

    for (key, value) in object {
      if key == "properties", let properties = value as? [String: Any] {
        let rewrittenProperties = rewriteProperties(properties)
        rewrittenObject[key] = rewrittenProperties.properties
        adjustedPropertyNames = rewrittenProperties.adjustedPropertyNames
        continue
      }

      rewrittenObject[key] = rewrite(value).node
    }

    if !adjustedPropertyNames.isEmpty,
      let required = rewrittenObject["required"] as? [String]
    {
      let filtered = required.filter { !adjustedPropertyNames.contains($0) }
      rewrittenObject["required"] = filtered
    }

    guard let oneOf = rewrittenObject["oneOf"] as? [Any] else {
      return RewriteResult(node: rewrittenObject, adjustedNullableSchema: false)
    }

    let nonNullBranches = oneOf.filter { !isNullSchema($0) }

    guard nonNullBranches.count != oneOf.count else {
      return RewriteResult(node: rewrittenObject, adjustedNullableSchema: false)
    }

    switch nonNullBranches.count {
    case 0:
      return RewriteResult(node: rewrittenObject, adjustedNullableSchema: false)
    case 1:
      rewrittenObject.removeValue(forKey: "oneOf")
      let merged = mergeCollapsedBranch(
        branch: nonNullBranches[0],
        into: rewrittenObject
      )
      return RewriteResult(node: merged, adjustedNullableSchema: true)
    default:
      rewrittenObject["oneOf"] = nonNullBranches
      return RewriteResult(node: rewrittenObject, adjustedNullableSchema: true)
    }
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

  private func rewriteProperties(_ properties: [String: Any]) -> RewrittenProperties {
    var rewrittenProperties: [String: Any] = [:]
    var adjustedPropertyNames = Set<String>()

    for (propertyName, propertyValue) in properties {
      let rewrittenProperty = rewrite(propertyValue)
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
}

private struct RewriteResult {
  let node: Any
  let adjustedNullableSchema: Bool
}

private struct RewrittenProperties {
  let properties: [String: Any]
  let adjustedPropertyNames: Set<String>
}

public enum OpenAPISanitizerCommand {
  public static func run(arguments: [String]) throws {
    guard arguments.count == 3 else {
      throw OpenAPISanitizerCommandError.invalidArguments
    }

    let inputURL = URL(fileURLWithPath: arguments[1])
    let outputURL = URL(fileURLWithPath: arguments[2])
    let data = try Data(contentsOf: inputURL)
    let rewritten = try OpenAPISanitizer().rewrite(data: data)
    try rewritten.write(to: outputURL)
  }
}

public enum OpenAPISanitizerCommandError: LocalizedError {
  case invalidArguments

  public var errorDescription: String? {
    switch self {
    case .invalidArguments:
      "Usage: openapi-sanitizer input.json output.json"
    }
  }
}

public enum OpenAPISanitizerBuildRule {
  public static let suffix = ".openapi.json.nullfix"

  public static func isSupportedInputFileName(_ fileName: String) -> Bool {
    fileName.hasSuffix(suffix) || fileName == "openapi.json.nullfix"
  }

  public static func outputFileName(for inputFileName: String) -> String {
    guard isSupportedInputFileName(inputFileName) else {
      return inputFileName
    }

    return String(inputFileName.dropLast(".nullfix".count))
  }
}
