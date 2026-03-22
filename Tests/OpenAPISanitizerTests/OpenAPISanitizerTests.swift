import Foundation
import Testing
@testable import OpenAPISanitizerCore

struct OpenAPISanitizerTests {
  @Test
  func collapsesSimpleNullableOneOf() throws {
    let input = try #require(jsonObject(
      """
      {
        "description": "nullable pet",
        "oneOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "type": "null" }
        ]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)

    #expect(output["description"] as? String == "nullable pet")
    #expect(output["$ref"] as? String == "#/components/schemas/Cat")
    #expect(output["oneOf"] == nil)
  }

  @Test
  func removesNullFromMultiBranchOneOf() throws {
    let input = try #require(jsonObject(
      """
      {
        "oneOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "$ref": "#/components/schemas/Dog" },
          { "type": "null" }
        ]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let oneOf = try #require(output["oneOf"] as? [[String: Any]])

    #expect(oneOf.count == 2)
    #expect(oneOf.contains { $0["$ref"] as? String == "#/components/schemas/Cat" })
    #expect(oneOf.contains { $0["$ref"] as? String == "#/components/schemas/Dog" })
    #expect(oneOf.allSatisfy { !$0.keys.contains("type") || $0["type"] as? String != "null" })
  }

  @Test
  func removesNullFromMultiBranchAnyOf() throws {
    let input = try #require(jsonObject(
      """
      {
        "anyOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "$ref": "#/components/schemas/Dog" },
          { "type": "null" }
        ]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let anyOf = try #require(output["anyOf"] as? [[String: Any]])

    #expect(anyOf.count == 2)
    #expect(anyOf.contains { $0["$ref"] as? String == "#/components/schemas/Cat" })
    #expect(anyOf.contains { $0["$ref"] as? String == "#/components/schemas/Dog" })
    #expect(anyOf.allSatisfy { !$0.keys.contains("type") || $0["type"] as? String != "null" })
  }

  @Test
  func rewritesDeeplyNestedSchemas() throws {
    let input = jsonObject(
      """
      {
        "components": {
          "schemas": {
            "Wrapper": {
              "properties": {
                "pet": {
                  "oneOf": [
                    { "$ref": "#/components/schemas/Cat" },
                    { "type": "null" }
                  ]
                }
              }
            }
          }
        },
        "paths": {
          "/pets": {
            "post": {
              "requestBody": {
                "content": {
                  "application/json": {
                    "schema": {
                      "items": {
                        "oneOf": [
                          { "$ref": "#/components/schemas/Dog" },
                          { "type": "null" }
                        ]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """
    )

    let output = try #require(OpenAPISanitizer().rewriteNode(input) as? [String: Any])
    let wrapper = dictionary(at: ["components", "schemas", "Wrapper"], in: output)
    let pet = dictionary(at: ["properties", "pet"], in: wrapper)
    let requestSchema = dictionary(
      at: [
        "paths",
        "/pets",
        "post",
        "requestBody",
        "content",
        "application/json",
        "schema",
      ],
      in: output
    )
    let items = requestSchema?["items"] as? [String: Any]

    #expect(pet?["$ref"] as? String == "#/components/schemas/Cat")
    #expect(pet?["oneOf"] == nil)
    #expect(items?["$ref"] as? String == "#/components/schemas/Dog")
    #expect(items?["oneOf"] == nil)
  }

  @Test
  func preservesMetadataWhenCollapsingOneOf() throws {
    let input = try #require(jsonObject(
      """
      {
        "description": "test",
        "title": "Example",
        "deprecated": true,
        "x-extra": "value",
        "oneOf": [
          { "type": "string" },
          { "type": "null" }
        ]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)

    #expect(output["description"] as? String == "test")
    #expect(output["title"] as? String == "Example")
    #expect(output["deprecated"] as? Bool == true)
    #expect(output["x-extra"] as? String == "value")
    #expect(output["type"] as? String == "string")
  }

  @Test
  func leavesAlreadyValidOneOfUnchanged() throws {
    let input = try #require(jsonObject(
      """
      {
        "oneOf": [
          { "type": "string" },
          { "type": "integer" }
        ]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let oneOf = try #require(output["oneOf"] as? [[String: Any]])

    #expect(oneOf.count == 2)
    #expect(oneOf.contains { $0["type"] as? String == "string" })
    #expect(oneOf.contains { $0["type"] as? String == "integer" })
  }

  @Test
  func cliWritesSanitisedJSON() throws {
    let directory = try temporaryDirectory()
    let inputURL = directory.appending(path: "input.json")
    let outputURL = directory.appending(path: "output.json")

    try Data(
      """
      {
        "oneOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "type": "null" }
        ]
      }
      """.utf8
    ).write(to: inputURL)

    try OpenAPISanitizerCommand.run(arguments: [
      "openapi-sanitizer",
      inputURL.path(),
      outputURL.path(),
    ])

    let outputObject = try #require(
      jsonObject(String(decoding: try Data(contentsOf: outputURL), as: UTF8.self))
      as? [String: Any]
    )

    #expect(outputObject["$ref"] as? String == "#/components/schemas/Cat")
    #expect(outputObject["oneOf"] == nil)
  }

  @Test
  func cliSupportsInPlaceRewrite() throws {
    let directory = try temporaryDirectory()
    let inputURL = directory.appending(path: "input.json")

    try Data(
      """
      {
        "anyOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "type": "null" }
        ]
      }
      """.utf8
    ).write(to: inputURL)

    try OpenAPISanitizerCommand.run(arguments: [
      "openapi-sanitizer",
      "--in-place",
      inputURL.path(),
    ])

    let outputObject = try #require(
      jsonObject(String(decoding: try Data(contentsOf: inputURL), as: UTF8.self))
      as? [String: Any]
    )

    #expect(outputObject["$ref"] as? String == "#/components/schemas/Cat")
    #expect(outputObject["anyOf"] == nil)
  }

  @Test
  func removesAdjustedPropertiesFromRequired() throws {
    let input = try #require(jsonObject(
      """
      {
        "type": "object",
        "properties": {
          "pet": {
            "oneOf": [
              { "$ref": "#/components/schemas/Cat" },
              { "type": "null" }
            ]
          },
          "name": {
            "type": "string"
          }
        },
        "required": ["pet", "name"]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let required = try #require(output["required"] as? [String])
    let pet = try #require((output["properties"] as? [String: Any])?["pet"] as? [String: Any])

    #expect(required == ["name"])
    #expect(pet["$ref"] as? String == "#/components/schemas/Cat")
  }

  @Test
  func removesAdjustedAnyOfPropertiesFromRequired() throws {
    let input = try #require(jsonObject(
      """
      {
        "type": "object",
        "properties": {
          "pet": {
            "anyOf": [
              { "$ref": "#/components/schemas/Cat" },
              { "type": "null" }
            ]
          },
          "name": {
            "type": "string"
          }
        },
        "required": ["pet", "name"]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let required = try #require(output["required"] as? [String])
    let pet = try #require((output["properties"] as? [String: Any])?["pet"] as? [String: Any])

    #expect(required == ["name"])
    #expect(pet["$ref"] as? String == "#/components/schemas/Cat")
  }

  @Test
  func keepsRequiredEntriesForUnchangedProperties() throws {
    let input = try #require(jsonObject(
      """
      {
        "type": "object",
        "properties": {
          "pet": {
            "oneOf": [
              { "$ref": "#/components/schemas/Cat" },
              { "$ref": "#/components/schemas/Dog" }
            ]
          }
        },
        "required": ["pet"]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let required = try #require(output["required"] as? [String])

    #expect(required == ["pet"])
  }

  @Test
  func removesOrphanRequiredEntriesWhenEnabled() throws {
    let input = try #require(jsonObject(
      """
      {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          }
        },
        "required": ["name", "ghost"]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(
      input,
      options: OpenAPISanitizerOptions(pruneOrphanRequiredProperties: true)
    )
    let required = try #require(output["required"] as? [String])

    #expect(required == ["name"])
  }

  @Test
  func keepsOrphanRequiredEntriesByDefault() throws {
    let input = try #require(jsonObject(
      """
      {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          }
        },
        "required": ["name", "ghost"]
      }
      """
    ) as? [String: Any])

    let output = OpenAPISanitizer().rewriteObject(input)
    let required = try #require(output["required"] as? [String])

    #expect(required == ["name", "ghost"])
  }

  @Test
  func cliLogsModificationsByDefault() throws {
    let directory = try temporaryDirectory()
    let inputURL = directory.appending(path: "input.json")
    var logs: [String] = []

    try Data(
      """
      {
        "anyOf": [
          { "$ref": "#/components/schemas/Cat" },
          { "type": "null" }
        ]
      }
      """.utf8
    ).write(to: inputURL)

    try OpenAPISanitizerCommand.run(
      arguments: ["openapi-sanitizer", "--in-place", inputURL.path()],
      log: { logs.append($0) }
    )

    #expect(!logs.isEmpty)
    #expect(logs.contains { $0.contains("Removed null branch") })
    #expect(logs.contains { $0.contains("Collapsed") })
  }

  @Test
  func cliQuietModeSuppressesLogs() throws {
    let directory = try temporaryDirectory()
    let inputURL = directory.appending(path: "input.json")
    var logs: [String] = []

    try Data(
      """
      {
        "type": "object",
        "properties": {
          "name": {
            "type": "string"
          }
        },
        "required": ["name", "ghost"]
      }
      """.utf8
    ).write(to: inputURL)

    try OpenAPISanitizerCommand.run(
      arguments: [
        "openapi-sanitizer",
        "--quiet",
        "--prune-orphan-required",
        "--in-place",
        inputURL.path(),
      ],
      log: { logs.append($0) }
    )

    #expect(logs.isEmpty)
  }

  @Test
  func libraryCanRewriteJSONInMemory() throws {
    let input = Data(
      """
      {
        "type": "object",
        "properties": {
          "pet": {
            "oneOf": [
              { "$ref": "#/components/schemas/Cat" },
              { "type": "null" }
            ]
          },
          "name": {
            "type": "string"
          }
        },
        "required": ["pet", "name", "ghost"]
      }
      """.utf8
    )

    let report = try OpenAPISanitizer().rewriteWithReport(
      data: input,
      options: OpenAPISanitizerOptions(pruneOrphanRequiredProperties: true)
    )
    let output = try #require(
      jsonObject(String(decoding: report.data, as: UTF8.self)) as? [String: Any]
    )
    let required = try #require(output["required"] as? [String])
    let pet = try #require((output["properties"] as? [String: Any])?["pet"] as? [String: Any])

    #expect(required == ["name"])
    #expect(pet["$ref"] as? String == "#/components/schemas/Cat")
    #expect(report.modifications.contains { $0.contains("Removed null branch") })
    #expect(report.modifications.contains { $0.contains("Removed orphan required entry") })
  }
}

private func jsonObject(_ json: String) -> Any {
  try! JSONSerialization.jsonObject(with: Data(json.utf8))
}

private func temporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

private func dictionary(at path: [String], in root: [String: Any]?) -> [String: Any]? {
  var current = root

  for key in path {
    current = current?[key] as? [String: Any]
  }

  return current
}
