// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YeollinBible",
    platforms: [.macOS(.v14)],
    targets: [
        // 성경 데이터 다루는 공용 코드 (앱과 DB 만드는 도구가 같이 씀)
        .target(name: "BibleCore", path: "Sources/BibleCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        // 공개 데이터로 Resources/bible.sqlite를 만드는 도구
        .executableTarget(name: "BibleBuilder", dependencies: ["BibleCore"], path: "Sources/BibleBuilder"),
        .executableTarget(name: "YeollinBible", dependencies: ["BibleCore"], path: "Sources/YeollinBible"),
        .testTarget(name: "BibleCoreTests", dependencies: ["BibleCore"], path: "Tests/BibleCoreTests"),
    ]
)
