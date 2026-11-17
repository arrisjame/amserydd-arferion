// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HabitBankCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HabitBankCore", targets: ["HabitBankCore"])
    ],
    targets: [
        .target(
            name: "HabitBankCore",
            path: "Amserydd Arferion/Amserydd Arferion/Domain"
        ),
        .testTarget(
            name: "HabitBankCoreTests",
            dependencies: ["HabitBankCore"],
            path: "Tests/HabitBankCoreTests"
        )
    ]
)
