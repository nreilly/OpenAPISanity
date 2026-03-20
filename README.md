# OpenAPI Sanitizer

`openapi-sanitizer` rewrites OpenAPI JSON documents before they are passed to
Swift OpenAPI Generator.

It removes `{"type":"null"}` branches from `oneOf` arrays and collapses trivial nullable
unions such as `oneOf: [A, null]` into `A`.

The package provides:

- a user-facing CLI executable: `openapi-sanitizer`

The recommended integration with Swift OpenAPI Generator is the CLI or the included
pre-build script.

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

## Xcode Pre-Build Script

If you are also using Swift OpenAPI Generator's build tool plugin, use a scheme pre-action
or external build step instead of a target build phase. The generator validates the
presence of `openapi.json` before target build phases run.

This repository includes a helper script:

[`Scripts/generate-openapi.sh`](Scripts/generate-openapi.sh)

Example invocation:

```sh
"$SRCROOT/../OpenAPISanity/Scripts/generate-openapi.sh" \
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

- `oneOf` branches matching `{ "type": "null" }` are removed.
- If one non-null branch remains, `oneOf` is collapsed into that branch.
- If a property schema loses a `null` branch, that property is also removed from the
  parent object's `required` array.
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

See [`Examples/nullable-oneof-input.json`](Examples/nullable-oneof-input.json)
and
[`Examples/nullable-oneof-output.json`](Examples/nullable-oneof-output.json).
