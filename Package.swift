// swift-tools-version: 6.0

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
  ],
  targets: [
    .target(
      name: "OpenAPISanitizerCore"
    ),
    .executableTarget(
      name: "OpenAPISanitizerCLI",
      dependencies: ["OpenAPISanitizerCore"]
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
