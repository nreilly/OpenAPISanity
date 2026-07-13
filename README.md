# OpenAPI Sanitizer

OpenAPI Sanitizer rewrites OpenAPI JSON documents before Swift OpenAPI Generator runs.
Its primary integration is a composite SwiftPM build-tool plugin that performs sanitisation and
generation as one incremental build pipeline under both SwiftPM and Xcode.

The package provides:

- `OpenAPISanitizedGenerator`, the recommended build-tool plugin
- `openapi-sanitizer`, a command-line executable
- `OpenAPISanitizerCommandPlugin`, a manual SwiftPM command plugin
- `OpenAPISanitizerCore`, an in-memory transformation library

## Package Integration

Add OpenAPI Sanitizer and Swift OpenAPI Runtime to the consuming package. Until the next tagged
OpenAPI Sanitizer release, use the `main` branch:

```swift
dependencies: [
  .package(
    url: "https://github.com/nreilly/OpenAPISanity.git",
    branch: "main"
  ),
  .package(
    url: "https://github.com/apple/swift-openapi-runtime",
    from: "1.11.0"
  ),
],
```

Attach `OpenAPISanitizedGenerator` to the target that consumes the generated API:

```swift
.target(
  name: "MyAPI",
  dependencies: [
    .product(
      name: "OpenAPIRuntime",
      package: "swift-openapi-runtime"
    ),
  ],
  plugins: [
    .plugin(
      name: "OpenAPISanitizedGenerator",
      package: "OpenAPISanity"
    ),
  ]
)
```

Do not also attach Swift OpenAPI Generator's `OpenAPIGenerator` plugin to the same target. The
composite plugin invokes the official generator itself.

Place these files in the target's source directory:

```text
Sources/MyAPI/
  openapi-source.json
  openapi-generator-config.yaml
  openapi-sanitizer-config.json  # optional
```

The plugin sanitises `openapi-source.json` into its build work directory and passes that output to
Swift OpenAPI Generator. It never rewrites the package source directory, and declared inputs and
outputs allow incremental builds.

The same manifest works when the package is opened or built within Xcode. No scheme pre-action,
target build phase, neighbouring checkout, or generated `openapi.json` is required. Xcode may ask
you to approve the package plugins when they first run.

## Sanitizer Configuration

`openapi-sanitizer-config.json` supports these options:

```json
{
  "makeNullablePropertiesOptional": false,
  "pruneOrphanRequiredProperties": false,
  "rewritePathParameterFormStyle": false
}
```

All options default to `false`.

`makeNullablePropertiesOptional` removes a property from its parent `required` array when the
property loses a null union branch. This changes the document contract because a required nullable
value is not equivalent to an absent value, so enable it only when required for generator
compatibility.

`pruneOrphanRequiredProperties` removes `required` entries that have no corresponding key in the
sibling `properties` object.

`rewritePathParameterFormStyle` rewrites `style: form` to `style: simple` on Parameter Objects
whose `in` value is `path`. OpenAPI path parameters allow `simple`, `label`, and `matrix` styles;
`simple` is the default. For array path parameters with `explode: false`, this preserves the
intended comma-separated path segment representation while avoiding inconsistent generated client
and type declarations.

## Library Usage

`OpenAPISanitizerCore` can transform JSON entirely in memory:

```swift
import Foundation
import OpenAPISanitizerCore

let inputData = Data(openAPIJSONString.utf8)
let report = try OpenAPISanitizer().rewriteWithReport(
  data: inputData,
  options: OpenAPISanitizerOptions(
    pruneOrphanRequiredProperties: true,
    makeNullablePropertiesOptional: true,
    rewritePathParameterFormStyle: true
  )
)

let sanitisedData = report.data
let modifications = report.modifications
```

The library supports macOS 10.15, iOS 13, tvOS 13, watchOS 6, and visionOS 1 or later. The CLI and
plugins remain host-side development tools.

## CLI Usage

Generate a separate sanitised document:

```sh
swift run openapi-sanitizer openapi-source.json openapi.json
```

Rewrite a file in place:

```sh
swift run openapi-sanitizer --in-place openapi.json
```

Load the same configuration used by the build plugin:

```sh
swift run openapi-sanitizer \
  --config openapi-sanitizer-config.json \
  openapi-source.json \
  openapi.json
```

Equivalent command-line flags are also available:

```sh
swift run openapi-sanitizer \
  --make-nullable-properties-optional \
  --prune-orphan-required \
  --rewrite-path-parameter-form-style \
  --quiet \
  openapi-source.json \
  openapi.json
```

To invoke the manual command plugin instead:

```sh
swift package --allow-writing-to-package-directory \
  sanitize-openapi \
  --config openapi-sanitizer-config.json \
  openapi-source.json \
  openapi.json
```

## Transformation Rules

- Null-only `{ "type": "null" }` branches are removed from `oneOf` and `anyOf` arrays.
- A union with one remaining branch is collapsed into that branch.
- Outer metadata such as `description`, `title`, `default`, `example`, `deprecated`, and `x-*`
  remains on a collapsed schema.
- Unions containing two or more non-null branches remain unions.
- All-null unions remain unchanged.
- Nullable properties remain required unless `makeNullablePropertiesOptional` is enabled.
- Orphan `required` entries remain unless `pruneOrphanRequiredProperties` is enabled.
- Path Parameter Objects retain `style: form` unless `rewritePathParameterFormStyle` is enabled.

The traversal applies recursively throughout the JSON document.

## Development

Run the unit suite:

```sh
swift test
```

Build the real consumer fixture to verify the complete plugin pipeline:

```sh
swift build --package-path IntegrationTests/ConsumerPackage
```

The fixture enables the nullable-property and path-parameter compatibility policies. It compiles
code against the generated optional Swift property and generates client and type declarations from
an array path parameter containing `style: form` and `explode: false`.
