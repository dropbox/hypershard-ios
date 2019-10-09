import SourceKittenFramework
import PathKit
import XcodeProj

// Tivan, the Hypershard's Test Collector
public enum Tivan {
    // MARK: - Public

    // returns a list of Path objects for test files enabled in Xcode
    static func getListOfTestFiles(inProject path: Path, target: String) -> [Path] {
        guard let project = try? XcodeProj(path: path.normalize()) else {
            fatalError("Invalid path or Xcode project.")
        }

        guard let testTarget = project.pbxproj.targets(named: target).first else {
            fatalError("The UI test target named \(target) is missing.")
        }

        return getListOfTestFiles(inTarget: testTarget,
                                  rootPath: path.normalize().parent())
    }

    static func getListOfTestFiles(inTarget target: PBXTarget, rootPath: Path) -> [Path] {
        guard let sourceFiles = try? target.sourceFiles() else {
            fatalError("Missing source files in the \(target) target.")
        }

        return sourceFiles
            .compactMap { (try? $0.fullPath(sourceRoot: rootPath)) ?? nil }
            .filter { $0.string.hasSuffix("Tests.swift") }
    }

    // returns a list of Path objects for valid test files
    static func getListOfTestFiles(inDirectory path: Path) -> [Path] {
        guard let allFiles = try? path.children() else {
            fatalError("Cannot obtain contents of the directory")
        }

        let allTests = allFiles.filter { $0.string.hasSuffix("Tests.swift") }
        return allTests
    }

    // returns the list of individual XCUITests in the test class
    static func getListOfTests(inTestFile path: Path) -> [String: [String]] {
        let testFile = File(path: path.string)
        guard let structure = try? Structure(file: testFile!) else {
            fatalError("Could not parse the XCUITest's Swift structure")
        }
        return getListOfTests(fromStructure: structure)
    }

    // MARK: - Internal

    // Enums and Structs for Tivan
    enum NodeType: String {
        case `class` = "source.lang.swift.decl.class"
        case instanceMethod = "source.lang.swift.decl.function.method.instance"
        case `extension` = "source.lang.swift.decl.extension" // NOTE:(bogo) this is meant for testing only

        var allowedAsRoot: Bool {
            switch self {
            case .class: return true
            case .extension: return false
            case .instanceMethod: return false
            }
        }
    }

    enum KeyNames {
        static let Kind = "key.kind"
        static let Name = "key.name"
        static let Substructure = "key.substructure"
    }

    struct Node {
        var type: NodeType
        var name: String
        var subnodes: [Node]
    }

    // gets lists of tests from a SourceKit Structure object
    static func getListOfTests(fromStructure structure: Structure) -> [String: [String]] {
        // there's a diagnostic wrapper we need to blow off first
        guard let diagnosticSubstructuresArray = structure.dictionary[KeyNames.Substructure] as? [[String: SourceKitRepresentable]] else {
            fatalError("The XCUITest doesn't make sense after removing the diagnostic wrapper.")
        }

        // parse all structures into Tivan nodes
        let structuresAsNodes = diagnosticSubstructuresArray.compactMap { (diagnosticSubstructure) -> Node? in
            parseStructure(diagnosticSubstructure)
        }

        // there will usually be a number of valid resulting nodes, including extensions, empty classes, and helper
        // classes. only classes with test methods, with name ending in `Test` are valid for collection purposes
        let filteredStructures = structuresAsNodes.filter { (node) -> Bool in
            if !node.type.allowedAsRoot {
                return false
            }

            if node.subnodes.count == 0 {
                return false
            }

            if !node.name.hasSuffix("Tests") {
                return false
            }

            return true
        }

        // finally, reduce the filtered structures into a dictionary
        let listOfTests = filteredStructures.reduce(into: [String: [String]]()) { (listOfTests, node) in
            let testsPerClass = node.subnodes.filter { (node) -> Bool in
                node.name.hasPrefix("test")
                }.map { (node) -> String in
                    // drop the braces at the end
                    String(node.name.dropLast(2))
                }

            listOfTests[node.name] = testsPerClass
        }

        return listOfTests
    }

    // parses the SourceKit's structure to obtain class/method representation
    static func parseStructure(_ structure: [String: SourceKitRepresentable]) -> Node? {
        guard let nodeTypeString = structure[KeyNames.Kind] as? String else {
            return nil
        }

        guard let nodeType = NodeType(rawValue: nodeTypeString) else {
            return nil
        }

        guard let nodeNameString = structure[KeyNames.Name] as? String else {
            return nil
        }

        guard let subnodesCollection = structure[KeyNames.Substructure] as? [[String: SourceKitRepresentable]] else {
            return Node(type: nodeType, name: nodeNameString, subnodes: [])
        }

        let subnodes = subnodesCollection.compactMap { (structure) -> Node? in
            parseStructure(structure)
        }

        return Node(type: nodeType, name: nodeNameString, subnodes: subnodes)
    }
}
