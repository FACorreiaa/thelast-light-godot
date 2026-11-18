// swift-tools-version: 6.0
// The parity oracle: runs the Swift reference simulation (game-proto at tag `swift-final`) and
// writes the data and golden traces the GDScript port is checked against.
// game-proto is private, so it is expected as a sibling checkout: ../game-proto relative to
// this repo. Only the generated data/ and tests/golden/ files are committed.
import PackageDescription

let package = Package(
    name: "oracle",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "LastLightCore", path: "../../../game-proto/LastLightCore"),
    ],
    targets: [
        .executableTarget(
            name: "oracle",
            dependencies: [
                .product(name: "ActionCore", package: "LastLightCore"),
                .product(name: "LastLightCore", package: "LastLightCore"),
            ]
        ),
    ]
)
