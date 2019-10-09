# ⚡ Hypershard
the ridiculously fast `XCUITest` collector

## About

Hypershard is a CLI tool that leverages SourceKit and Swift's Abstract Syntax Tree (AST) to parse our `XCUITest` files for the purposes of test collection. It makes a couple of assumptions about how the `XCUITest`s are organized:
 - it assumes that all files containing tests have suffix `Tests.swift`,
 - it assumes all test methods' names begin with the `test` prefix,

In benchmarks, Hypershard takes, on average, under 0.06s per collection of tests from Dropbox and Paper iOS apps, down from roughly ~15 minutes it tooks us to collect tests by building of the individual apps.

Check out the sibling Hypershard tool for Android, [dropbox/hypershard-android](https://github.com/dropbox/hypershard-android)!

## Building
Hypershard is built using Swift Package Manager.

To build Hypershard for development purposes, enter Hypershard's root directory and run:

```> swift build```

This will check out the relevant dependencies and build the debug binary into the `.build` folder. The path for the resulting binary will be provided in the `swift build`'s output.

To build Hypershard binary for direct distribution, enter Hypershard's root directory and run:

```swift build -c release```

The resulting binary will be placed in the `.build/release/hypershard`.

## Running
To run Hypershard, you have to follow this CLI invocation:

`> hypershard TEST_TARGET_NAME ROOT_PATH --phase PHASE_NAME --path PATH --cmd CMD --output-file OUTPUT_PATH`

 - `TEST_TARGET_NAME` – the name of the Xcode test target containing the UI tests,
 - `ROOT_PATH` – either a path where all the `XCUITest`s clases are stored, or the path of the Xcode project containing `TEST_TARGET_NAME`,
 - `PHASE_NAME` – *optional* – name of the Changes phase,
 - `PATH` – *optional* – the custom `PATH` variable,
 - `CMD` – *optional* – the command to run each test with,
 - `OUTPUT_PATH` – *optional* – the path where the output JSON should be saved, if it's not passed, the output will be printed

The first two parameters are required. You need to provide all optional parameters if you want an output consumable by [Changes](https://github.com/dropbox/changes). The final parameter is a path where the output JSON should be saved.

For CI systems, we recommend to *not* rebuild Hypershard every time, and to store and use a static binary instead.

## Output
There are two possible outputs from Hypershard:
 - an error due to a malformed Swift file or an incomprehensible test - the tool will output relevant information before aborting,
 - a JSON file containing a list of all available `XCUITest`s.

## Testing
You can test Hypershard using Swift Package Manager, simply by running the following command in the Hypershard's root:

```> swift test```
