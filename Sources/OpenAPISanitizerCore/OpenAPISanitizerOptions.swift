import Foundation

/// Options controlling compatibility transformations applied to an OpenAPI document.
public struct OpenAPISanitizerOptions: Codable, Equatable, Sendable {
  /// Whether orphan entries are removed from `required` arrays.
  public let pruneOrphanRequiredProperties: Bool

  /// Whether nullable properties are removed from their parent `required` array.
  public let makeNullablePropertiesOptional: Bool

  /// Whether invalid `form` styles on path parameters are rewritten to `simple`.
  public let rewritePathParameterFormStyle: Bool

  /// Creates a set of sanitisation options.
  ///
  /// - Parameters:
  ///   - pruneOrphanRequiredProperties: Whether orphan `required` entries are removed.
  ///   - makeNullablePropertiesOptional: Whether nullable properties become optional.
  ///   - rewritePathParameterFormStyle: Whether invalid path parameter styles are rewritten.
  public init(
    pruneOrphanRequiredProperties: Bool = false,
    makeNullablePropertiesOptional: Bool = false,
    rewritePathParameterFormStyle: Bool = false
  ) {
    self.pruneOrphanRequiredProperties = pruneOrphanRequiredProperties
    self.makeNullablePropertiesOptional = makeNullablePropertiesOptional
    self.rewritePathParameterFormStyle = rewritePathParameterFormStyle
  }

  /// Creates options by decoding a configuration document.
  ///
  /// Missing Boolean values default to `false`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      pruneOrphanRequiredProperties: try container.decodeIfPresent(
        Bool.self,
        forKey: .pruneOrphanRequiredProperties
      ) ?? false,
      makeNullablePropertiesOptional: try container.decodeIfPresent(
        Bool.self,
        forKey: .makeNullablePropertiesOptional
      ) ?? false,
      rewritePathParameterFormStyle: try container.decodeIfPresent(
        Bool.self,
        forKey: .rewritePathParameterFormStyle
      ) ?? false
    )
  }
}
