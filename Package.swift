// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "OpenAPISanity",
  platforms: [
    .macOS(.v13),
    .iOS(.v18),
    .visionOS(.v2),
  ],
  products: [
    .executable(
      name: "openapi-sanitizer",
      targets: ["OpenAPISanitizerExecutable"]
    ),
    .library(
      name: "OpenAPISanitizerCore",
      targets: ["OpenAPISanitizerCore"]
    ),
    .plugin(
      name: "OpenAPISanitizerCommandPlugin",
      targets: ["OpenAPISanitizerCommandPlugin"]
    ),
  ],
  targets: [
    .target(
      name: "OpenAPISanitizerCore"
    ),
    .executableTarget(
      name: "OpenAPISanitizerExecutable",
      dependencies: ["OpenAPISanitizerCore"]
    ),
    .executableTarget(
      name: "OpenAPISanitizerCommandTool",
      dependencies: ["OpenAPISanitizerCore"]
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
      dependencies: ["OpenAPISanitizerCommandTool"]
    ),
    .testTarget(
      name: "OpenAPISanitizerTests",
      dependencies: [
        "OpenAPISanitizerCore",
      ]
    ),
  ]
)
