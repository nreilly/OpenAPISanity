import Foundation

public struct OpenAPISanitizer {
  public init() {}

  public func rewriteNode(_ node: Any) -> Any {
    switch node {
    case let object as [String: Any]:
      rewriteObject(object)
    case let array as [Any]:
      array.map(rewriteNode)
    default:
      node
    }
  }

  public func rewriteObject(_ object: [String: Any]) -> [String: Any] {
    var rewrittenObject = object.mapValues(rewriteNode)

    guard let oneOf = rewrittenObject["oneOf"] as? [Any] else {
      return rewrittenObject
    }

    let nonNullBranches = oneOf.filter { !isNullSchema($0) }

    guard nonNullBranches.count != oneOf.count else {
      return rewrittenObject
    }

    switch nonNullBranches.count {
    case 0:
      return rewrittenObject
    case 1:
      rewrittenObject.removeValue(forKey: "oneOf")
      return mergeCollapsedBranch(
        branch: nonNullBranches[0],
        into: rewrittenObject
      )
    default:
      rewrittenObject["oneOf"] = nonNullBranches
      return rewrittenObject
    }
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
