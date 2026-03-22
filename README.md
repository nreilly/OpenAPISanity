# OpenAPI Sanitizer

`openapi-sanitizer` rewrites OpenAPI JSON documents before they are passed to
Swift OpenAPI Generator.

It removes `{"type":"null"}` branches from `oneOf` arrays and collapses trivial nullable
unions such as `oneOf: [A, null]` into `A`. The same rewrite is applied to `anyOf`.

The library target supports iOS, macOS, and visionOS. The CLI and SwiftPM plugin are
host-side developer tools.

The package provides:

- a user-facing CLI executable: `openapi-sanitizer`
- a reusable library product: `OpenAPISanitizerCore`
- a SwiftPM command plugin: `OpenAPISanitizerCommandPlugin`

The recommended integration with Swift OpenAPI Generator is the CLI or the included
pre-build script.

## Library Usage

`OpenAPISanitizerCore` can be embedded directly in iOS, macOS, and visionOS apps.
The library works entirely in memory, so JSON does not need to be written to disk
before it is sanitised.

```swift
import Foundation
import OpenAPISanitizerCore

let inputData = Data(openAPIJSONString.utf8)
let sanitizer = OpenAPISanitizer()
let report = try sanitizer.rewriteWithReport(
  data: inputData,
  options: OpenAPISanitizerOptions(pruneOrphanRequiredProperties: true)
)

let sanitisedData = report.data
let modifications = report.modifications
```

The CLI and command plugin remain host-side developer tools. The library target is the
piece intended for runtime use on Apple platforms.

## CLI Usage

Build or run it with SwiftPM:

```sh
swift run openapi-sanitizer openapi.json openapi-sanitized.json
```

Or rewrite a file in place:

```sh
swift run openapi-sanitizer --in-place openapi.json
```

Enable optional pruning for `required` entries that do not exist in the sibling
`properties` map:

```sh
swift run openapi-sanitizer --prune-orphan-required --in-place openapi.json
```

By default, each modification is written to standard output so it appears in build
logs. Suppress that output with `--quiet`:

```sh
swift run openapi-sanitizer --quiet --in-place openapi.json
```

Then feed the sanitised document into Swift OpenAPI Generator:

```sh
swift run swift-openapi-generator generate \
  --input openapi-sanitized.json \
  --config openapi-generator-config.yaml \
  --output-directory Generated/
```

## Command Plugin Usage

For Swift packages, the command plugin can rewrite files in the package directory:

```sh
swift package --allow-writing-to-package-directory sanitize-openapi path/to/openapi.json
```

This defaults to in-place rewriting for a single path. You can also pass the same CLI
shapes as the executable:

```sh
swift package --allow-writing-to-package-directory sanitize-openapi --in-place path/to/openapi.json
swift package --allow-writing-to-package-directory sanitize-openapi --quiet path/to/openapi.json
swift package --allow-writing-to-package-directory sanitize-openapi --prune-orphan-required path/to/openapi.json
swift package --allow-writing-to-package-directory sanitize-openapi input.json output.json
```

## Xcode Pre-Build Script

If you are also using Swift OpenAPI Generator's build tool plugin, use a scheme pre-action
or external build step instead of a target build phase. The generator validates the
presence of `openapi.json` before target build phases run.

This repository includes a helper script:

[`Scripts/generate-openapi.sh`](Scripts/generate-openapi.sh)

Example invocation:

```sh
"$SRCROOT/../OpenAPISanity/Scripts/generate-openapi.sh" \
  --prune-orphan-required \
  --quiet \
  "$SRCROOT/Path/To/openapi.json.nullfix" \
  "$SRCROOT/Path/To/openapi.json" \
  "$SRCROOT/../OpenAPISanity"
```

Recommended Xcode setup:

- keep `openapi.json.nullfix` as the edited source file
- generate `openapi.json` into the same source directory before the build starts
- add `openapi.json` to the Xcode target so `OpenAPIGenerator` can discover it
- run the script from a scheme pre-action, or from CI before `xcodebuild`

The pre-build script is the recommended Xcode integration when you are also using
Swift OpenAPI Generator's `OpenAPIGenerator` plugin.

## Transformation Rules

- `oneOf` and `anyOf` branches matching `{ "type": "null" }` are removed.
- If one non-null branch remains, `oneOf` or `anyOf` is collapsed into that branch.
- If a property schema loses a `null` branch, that property is also removed from the
  parent object's `required` array.
- Optionally, entries in `required` that are not present in the sibling `properties`
  map can also be removed with `--prune-orphan-required`.
- Outer schema metadata is preserved when collapsing, including fields such as
  `description`, `title`, `default`, `example`, `deprecated`, and `x-*`.
- If two or more non-null branches remain, the union keyword is kept.
- If all branches are null, the schema is left unchanged.
- Each applied rewrite is logged unless `--quiet` is used.

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

See [`Examples/nullable-oneof-input.json`](Examples/nullable-oneof-input.json)
and
[`Examples/nullable-oneof-output.json`](Examples/nullable-oneof-output.json).
