import Foundation
import PathKit
import Commander

public class CLI {
    // MARK: - Public

    // returns a Cmmander-powered entry point to the Hypershard's CLI
    public class func entryPoint() -> CommandType {
        return command(
            Argument<String>("testTargetName", description: "name of the Xcode target for XCUITests"),
            Argument<Path>("rootPath", description: "path to either the directory containing all XCUITests or the Xcode project"),
            Option<String>("path", default: "", description: "The relevant PATH for shards"),

            Option<String>("output-tests-only", default: "false", description: "When set to true, only output the test list"),

            Option<String>("cmd", default: "", description: "The command to launch Xcode with"),
            Option<String>("services-required", default: "false", description: "Whether need to wait for SandCastle init"),
            Option<String>("phase", default: "XCUI test shard", description: "The build phase for which the shard is prepared"),
            Option<Path>("output-file", default: Path(), description: "File to output the final JSON to")
        ) { testTargetName, rootPath, path,
            testsOnly,
            cmd, servicesRequired, phase, outputFilePath in
            let configuration = Configuration(testTargetName: testTargetName,
                                              rootPath: rootPath)

            let tests = collectTests(withConfiguration: configuration)
            if testsOnly.boolValue {
                print(tests)
            } else {
                let outputFile = OutputFile(path: path,
                                            phase: phase,
                                            cmd: cmd,
                                            env: servicesRequired.boolValue ? ["SERVICES_REQUIRED": "1"] : [:],
                                            tests: tests)
                outputTests(outputFile: outputFile, outputFilePath: outputFilePath)
            }
        }
    }

    // MARK: - Internal

    struct Configuration {
        let testTargetName: String
        let rootPath: Path
    }

    struct OutputFile: Codable {
        let path: String
        let phase: String
        let cmd: String
        let env: [String: String]
        let tests: [ String ]
    }

    class func collectTests(withConfiguration configuration: Configuration) -> [ String ] {
        let testPaths = { () -> [Path] in
            let path = configuration.rootPath
            if path.string.hasSuffix(".xcodeproj") {
                return Tivan.getListOfTestFiles(inProject: path.normalize(),
                                                target: configuration.testTargetName)
            }

            // search the root test directory for test files
            return Tivan.getListOfTestFiles(inDirectory: path.normalize())
        }()

        // evaluate each test file for XCUITests
        let testNames = testPaths.reduce(into: [String: [String]](), { (testClassesToTestsMap, path) in
            let testClassesFromFile = Tivan.getListOfTests(inTestFile: path.normalize())
            testClassesFromFile.forEach({ (testName, tests) in
                testClassesToTestsMap[testName] = tests
            })
        })

        // flatten the sub-arrays into one array of tests
        let flatListOfTests = testNames.flatMap { (arg) -> [String] in
            let (testClassName, testList) = arg
            return testList.map({ (testName) -> String in
                "\(configuration.testTargetName).\(testClassName).\(testName)"
            })
        }

        return flatListOfTests
    }

    class func outputTests(outputFile: OutputFile, outputFilePath: Path) {
        guard let jsonData = try? JSONEncoder().encode(outputFile) else {
            fatalError("Could not encode the output as valid JSON")
        }

        // if the output file path is empty, just print to screen
        if outputFilePath == Path() {
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                fatalError("Could not obtain the final JSON string")
            }
            print(jsonString)
        } else {
            do {
                try jsonData.write(to: outputFilePath.normalize().url)
            } catch {
                fatalError("Unable to write the output JSON file")
            }
        }
    }
}

extension String {
    var boolValue: Bool {
        return (self as NSString).boolValue
    }
}
