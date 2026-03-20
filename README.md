# OpenAPI Sanitizer

`openapi-sanitizer` is a Swift command-line tool that rewrites OpenAPI JSON documents
before they are passed to Swift OpenAPI Generator.

It removes `{"type":"null"}` branches from `oneOf` arrays and collapses trivial nullable
unions such as `oneOf: [A, null]` into `A`.

## Usage

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
