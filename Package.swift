// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "OpenAPISanity",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .visionOS(.v1),
  ],
  products: [
    .executable(
      name: "openapi-sanitizer",
      targets: ["openapi-sanitizer"]
    ),
    .library(
      name: "OpenAPISanitizerCore",
      targets: ["OpenAPISanitizerCore"]
    ),
    .plugin(
      name: "OpenAPISanitizerCommandPlugin",
      targets: ["OpenAPISanitizerCommandPlugin"]
    ),
    .plugin(
      name: "OpenAPISanitizedGenerator",
      targets: ["OpenAPISanitizedGenerator"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-openapi-generator",
      .upToNextMinor(from: "1.13.0")
    ),
  ],
  targets: [
    .target(
      name: "OpenAPISanitizerCore"
    ),
    .target(
      name: "OpenAPISanitizerCommand",
      dependencies: ["OpenAPISanitizerCore"]
    ),
    .executableTarget(
      name: "openapi-sanitizer",
      dependencies: ["OpenAPISanitizerCommand"]
    ),
    .plugin(
      name: "OpenAPISanitizerCommandPlugin",
      capability: .command(
        intent: .custom(
          verb: "sanitize-openapi",
          description: "Sanitise OpenAPI JSON files in place."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "To rewrite OpenAPI documents in the package directory."
          ),
        ]
      ),
      dependencies: ["openapi-sanitizer"]
    ),
    .plugin(
      name: "OpenAPISanitizedGenerator",
      capability: .buildTool(),
      dependencies: [
        "openapi-sanitizer",
        .product(
          name: "swift-openapi-generator",
          package: "swift-openapi-generator"
        ),
      ]
    ),
    .testTarget(
      name: "OpenAPISanitizerTests",
      dependencies: [
        "OpenAPISanitizerCore",
        "OpenAPISanitizerCommand",
      ]
    ),
  ]
)
