// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RichTextPrimitive",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "RichTextPrimitive", targets: ["RichTextPrimitive"]),
        .library(name: "RichTextPrimitiveAI", targets: ["RichTextPrimitiveAI"]),
    ],
    dependencies: [
        .package(path: "../UndoPrimitive"),
        .package(path: "../ClipboardPrimitive"),
        .package(path: "../ColorPickerPrimitive"),
        .package(path: "../KeyboardShortcutPrimitive"),
        .package(path: "../SpellCheckKit"),
        .package(path: "../SyntaxHighlightPrimitive"),
        .package(path: "../TypographyPrimitive"),
    ],
    targets: [
        .target(
            name: "RichTextPrimitive",
            dependencies: [
                .product(name: "UndoPrimitive", package: "UndoPrimitive"),
                .product(name: "ClipboardPrimitive", package: "ClipboardPrimitive"),
                .product(name: "ColorPickerPrimitive", package: "ColorPickerPrimitive"),
                .product(name: "KeyboardShortcutProtocol", package: "KeyboardShortcutPrimitive"),
                .product(name: "SpellCheckKit", package: "SpellCheckKit"),
                .product(name: "SyntaxHighlightPrimitive", package: "SyntaxHighlightPrimitive"),
                .product(name: "TypographyPrimitive", package: "TypographyPrimitive"),
            ]
        ),
        .target(
            name: "RichTextPrimitiveAI",
            dependencies: ["RichTextPrimitive"]
        ),
        .testTarget(
            name: "RichTextPrimitiveTests",
            dependencies: [
                "RichTextPrimitive",
                .product(name: "SpellCheckKit", package: "SpellCheckKit"),
            ]
        ),
        .testTarget(
            name: "RichTextPrimitiveAITests",
            dependencies: ["RichTextPrimitiveAI", "RichTextPrimitive"]
        ),
    ]
)
