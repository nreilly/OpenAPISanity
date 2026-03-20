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
