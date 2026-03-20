# OpenAPI Sanitizer

`openapi-sanitizer` rewrites OpenAPI JSON documents before they are passed to
Swift OpenAPI Generator.

It removes `{"type":"null"}` branches from `oneOf` arrays and collapses trivial nullable
unions such as `oneOf: [A, null]` into `A`.

The package vends both:

- a CLI executable: `openapi-sanitizer`
- a build tool plugin: `OpenAPISanitizerPlugin`

## CLI Usage

Build or run it with SwiftPM:

```sh
swift run openapi-sanitizer openapi.json openapi-sanitized.json
```

Then feed the sanitised document into Swift OpenAPI Generator:

```sh
swift run swift-openapi-generator generate \
  --input openapi-sanitized.json \
  --config openapi-generator-config.yaml \
  --output-directory Generated/
```

## Build Tool Plugin Usage

Add the package as a dependency, then attach `OpenAPISanitizerPlugin` to the target that
contains your OpenAPI document:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "Example",
  dependencies: [
    .package(path: "../OpenAPISanity"),
  ],
  targets: [
    .target(
      name: "APISpec",
      plugins: [
        .plugin(name: "OpenAPISanitizerPlugin", package: "OpenAPISanity"),
      ]
    ),
  ]
)
```

The plugin looks for files named `openapi.json` or `*.openapi.json` in the target and
emits matching `*-sanitized.json` files into the plugin work directory.

Examples:

- `openapi.json` -> `openapi-sanitized.json`
- `petstore.openapi.json` -> `petstore.openapi-sanitized.json`

The plugin supports both SwiftPM targets and Xcode targets.

## Plugin Limitation

SwiftPM build tool plugins cannot rewrite source files in place. This plugin therefore
generates a derived JSON file instead of mutating the original spec.

If you want Swift OpenAPI Generator to consume the sanitised file automatically, the next
step is usually to wrap both operations in a single plugin or script-driven build step.
This package currently provides the sanitiser as a separate build tool plugin.

## Transformation Rules

- `oneOf` branches matching `{ "type": "null" }` are removed.
- If one non-null branch remains, `oneOf` is collapsed into that branch.
- Outer schema metadata is preserved when collapsing, including fields such as
  `description`, `title`, `default`, `example`, `deprecated`, and `x-*`.
- If two or more non-null branches remain, `oneOf` is kept.
- If all branches are null, the schema is left unchanged.

The traversal is recursive and applies across the full JSON document, including nested
schemas in `components`, `paths`, `properties`, `items`, composition keywords, and any
other schema-shaped object.

## Example

Input:

```json
{
  "description": "nullable pet",
  "oneOf": [
    { "$ref": "#/components/schemas/Cat" },
    { "type": "null" }
  ]
}
```

Output:

```json
{
  "$ref": "#/components/schemas/Cat",
  "description": "nullable pet"
}
```

See [`Examples/nullable-oneof-input.json`](/Users/nathan/Documents/code/OpenAPISanity/Examples/nullable-oneof-input.json)
and
[`Examples/nullable-oneof-output.json`](/Users/nathan/Documents/code/OpenAPISanity/Examples/nullable-oneof-output.json).
