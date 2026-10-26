// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// swift-tools-version: 6.0

// esp-swift-mcpwm: built by swift_package() from esp-swift-support, with ESP-IDF's headers.

import PackageDescription

let package = Package(
    name: "esp-swift-mcpwm",
    products: [
        .library(name: "MCPWM", targets: ["MCPWM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nixit22/esp-swift-support.git", from: "0.2.0"),
        .package(url: "https://github.com/nixit22/esp-swift-platform.git", from: "0.1.0"),
    ],
    targets: [
        // include/ESP_MCPWM.h is the umbrella header: SwiftPM generates the module map.
        .target(
            name: "ESP_MCPWM",
            dependencies: [.product(name: "SwiftSupport", package: "esp-swift-support")]
        ),
        .target(
            name: "MCPWM",
            dependencies: [
                "ESP_MCPWM",
                .product(name: "Platform", package: "esp-swift-platform"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
