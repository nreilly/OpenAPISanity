// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "OpenAPISanityConsumer",
  platforms: [
    .macOS(.v13),
  ],
  dependencies: [
    .package(path: "../.."),
    .package(
      url: "https://github.com/apple/swift-openapi-runtime",
      from: "1.11.0"
    ),
  ],
  targets: [
    .executableTarget(
      name: "Consumer",
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
    ),
  ]
)
