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
      targets: ["OpenAPISanitizerExecutable"]
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
      name: "OpenAPISanitizerExecutable",
      dependencies: ["OpenAPISanitizerCore"]
    ),
    .testTarget(
      name: "OpenAPISanitizerTests",
      dependencies: [
        "OpenAPISanitizerCore",
      ]
    ),
  ]
)
