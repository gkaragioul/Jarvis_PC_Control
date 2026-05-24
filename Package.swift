// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JarvisPCControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "JarvisPCControl", targets: ["JarvisPCControl"])
    ],
    targets: [
        .executableTarget(
            name: "JarvisPCControl",
            path: "Sources/JarvisPCControl"
        )
    ]
)
