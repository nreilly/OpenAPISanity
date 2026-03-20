// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "OpenAPISanity",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .executable(
      name: "openapi-sanitizer",
      targets: ["OpenAPISanitizerCLI"]
    ),
    .library(
      name: "OpenAPISanitizerCore",
      targets: ["OpenAPISanitizerCore"]
    ),
    .plugin(
      name: "OpenAPISanitizerPlugin",
      targets: ["OpenAPISanitizerPlugin"]
    ),
  ],
  targets: [
    .target(
      name: "OpenAPISanitizerCore"
    ),
    .executableTarget(
      name: "OpenAPISanitizerCLI",
      dependencies: ["OpenAPISanitizerCore"]
    ),
    .plugin(
      name: "OpenAPISanitizerPlugin",
      capability: .buildTool(),
      dependencies: ["OpenAPISanitizerCLI"]
    ),
    .testTarget(
      name: "OpenAPISanitizerTests",
      dependencies: [
        "OpenAPISanitizerCLI",
        "OpenAPISanitizerCore",
      ]
    ),
  ]
)
