// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LivePhotoStudioMediaTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LivePhotoStudio",
            path: "LivePhotoStudio",
            exclude: [
                "Assets.xcassets", "LivePhotoStudioApp.swift", "PhotoLibrary.swift",
                "StudioModel.swift", "StudioView.swift"
            ]
        ),
        .testTarget(
            name: "LivePhotoStudioTests",
            dependencies: ["LivePhotoStudio"],
            path: "LivePhotoStudioTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
