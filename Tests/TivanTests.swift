// Hypershard - test for Tivan

import XCTest
import PathKit
import SourceKittenFramework
@testable import HypershardCore

typealias MockSubstructure = [String: SourceKitRepresentable]

extension Dictionary where Key == String, Value == SourceKitRepresentable {
    func asStructure() -> Structure {
        return Structure(sourceKitResponse: self)
    }
}

struct TivanMocks {

    // Specific object type mocks

    static func mockDiagnosticWrapper(_ substructures: [MockSubstructure]) -> MockSubstructure {
        return [
            // the diagnostic file wrapper
            Tivan.KeyNames.Substructure: substructures
        ]
    }

    static func mockClass(named className: String, withMethods methods: [MockSubstructure]) -> MockSubstructure {
        return self.mockObject(ofKind: Tivan.NodeType.class, named: className, withSubstructure: methods)
    }

    static func mockMethod(named methodName: String) -> MockSubstructure {
        return self.mockObject(ofKind: Tivan.NodeType.instanceMethod, named: methodName + "()")
    }

    static func mockExtension(named extensionName: String) -> MockSubstructure {
        return self.mockObject(ofKind: Tivan.NodeType.extension, named: extensionName)
    }

    // Generic object mocks

    static func mockObject(ofKind kind: Tivan.NodeType) -> MockSubstructure {
        return [
            Tivan.KeyNames.Kind: kind.rawValue
        ]
    }

    static func mockObject(ofKind kind: Tivan.NodeType, named name: String) -> MockSubstructure {
        return [
            Tivan.KeyNames.Kind: kind.rawValue,
            Tivan.KeyNames.Name: name
        ]
    }

    static func mockObject(ofKind kind: Tivan.NodeType,
                           named name: String,
                           withSubstructure substructure: [MockSubstructure]) -> MockSubstructure {
        return [
            Tivan.KeyNames.Kind: kind.rawValue,
            Tivan.KeyNames.Name: name,
            Tivan.KeyNames.Substructure: substructure
        ]
    }
}

class TivanTests: XCTestCase {
    enum ClassNames {
        static let firstClassName = "FirstClassTests"
        static let secondClassName = "SecondClassTests"
        static let invalidClassName = "InvalidClassTest"
    }

    enum MethodNames {
        static let setupMethodName = "setUp"
        static let firstTestMethodName = "testMethod"
        static let secondTestMethodName = "testMethod2"
        static let invalidTestMethodName = "yoloMethod"
    }

    func testXcodeReading() {
        let paths = Tivan.getListOfTestFiles(inProject: Path("Resources/Xcode/TivanTests.xcodeproj"),
                                             target: "TivanUITests")
        XCTAssert(paths.count > 0, "There must be a non-zero list of files with UI tests returned.")

        guard let firstPath = paths.first else {
            XCTFail("There must be at least one test file parsed out of the project.")
            return
        }

        let tests = Tivan.getListOfTests(inTestFile: firstPath)
        guard let testClass = tests.values.first else {
            XCTFail("There must be at least one test class parsed in the test file.")
            return
        }

        XCTAssert(testClass.count > 0, "There must be at least one test case parsed out of the test class.")
    }

    func testDiagnosticStripping() {
        let mockStructure = TivanMocks.mockDiagnosticWrapper([])

        let listOfTests = Tivan.getListOfTests(fromStructure: mockStructure.asStructure())

        XCTAssertEqual(listOfTests.keys.count, 0, "The test list should be completely empty")
    }

    func testBasicTestCollecting() {
        let mockStructure = TivanMocks.mockDiagnosticWrapper([
            TivanMocks.mockClass(named: ClassNames.firstClassName,
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.setupMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.secondTestMethodName)
                                    ])
            ])

        let listOfTests = Tivan.getListOfTests(fromStructure: mockStructure.asStructure())
        XCTAssertEqual(listOfTests.count, 1)
        XCTAssertTrue(listOfTests.keys.contains(ClassNames.firstClassName))

        guard let testsForClass = listOfTests[ClassNames.firstClassName] else {
            XCTAssert(false, "Cannot open the test results")
            return
        }

        XCTAssertEqual(testsForClass.count, 2, "The test list should contain only two tests")
        XCTAssertTrue(testsForClass.contains(MethodNames.firstTestMethodName))
        XCTAssertTrue(testsForClass.contains(MethodNames.secondTestMethodName))
        XCTAssertFalse(testsForClass.contains(MethodNames.setupMethodName))
        XCTAssertFalse(testsForClass.contains(MethodNames.invalidTestMethodName))
    }

    func testSkippingInvalidClasses() {
        let mockStructure = TivanMocks.mockDiagnosticWrapper([
            TivanMocks.mockClass(named: ClassNames.firstClassName, withMethods: []),
            TivanMocks.mockClass(named: ClassNames.invalidClassName, withMethods: [])
            ])

        let listOfTests = Tivan.getListOfTests(fromStructure: mockStructure.asStructure())
        XCTAssertEqual(listOfTests.keys.count, 0, "There should be no valid classes")
    }

    func testMultipleClasses() {
        let mockStructure = TivanMocks.mockDiagnosticWrapper([
            TivanMocks.mockClass(named: ClassNames.firstClassName,
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.setupMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName)
                                    ]),
            TivanMocks.mockClass(named: ClassNames.secondClassName,
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.setupMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.secondTestMethodName)
                                    ])
            ])

        let listOfTests = Tivan.getListOfTests(fromStructure: mockStructure.asStructure())
        XCTAssertEqual(listOfTests.keys.count, 2)

        XCTAssertTrue(listOfTests.keys.contains(ClassNames.firstClassName))
        XCTAssertEqual(listOfTests[ClassNames.firstClassName]?.count, 1)

        XCTAssertTrue(listOfTests.keys.contains(ClassNames.secondClassName))
        XCTAssertEqual(listOfTests[ClassNames.secondClassName]?.count, 2)
    }

    func testForStrippingNonTestClasses() {
        let mockStructure = TivanMocks.mockDiagnosticWrapper([
            TivanMocks.mockExtension(named: "TestsExtension"),
            TivanMocks.mockClass(named: "TestingMock",
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName)
                                    ]),
            TivanMocks.mockClass(named: ClassNames.firstClassName,
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.setupMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName)
                                    ]),
            TivanMocks.mockClass(named: ClassNames.secondClassName,
                                 withMethods: [
                                    TivanMocks.mockMethod(named: MethodNames.setupMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.firstTestMethodName),
                                    TivanMocks.mockMethod(named: MethodNames.secondTestMethodName)
                                    ])
            ])

        let listOfTests = Tivan.getListOfTests(fromStructure: mockStructure.asStructure())
        XCTAssertEqual(listOfTests.count, 2, "Incorrect number of test classes")

        XCTAssertTrue(listOfTests.keys.contains(ClassNames.firstClassName))
        XCTAssertTrue(listOfTests[ClassNames.firstClassName]?.count == 1)

        XCTAssertTrue(listOfTests.keys.contains(ClassNames.secondClassName))
        XCTAssertTrue(listOfTests[ClassNames.secondClassName]?.count == 2)
    }
}
