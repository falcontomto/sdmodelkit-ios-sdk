import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(SDModelKitMacros)
import SDModelKitMacros

let testMacros: [String: Macro.Type] = [
    "DomainModel": DomainModelMacro.self,
    "UseRelationship": InertAttributeMacro.self,
]
#endif

final class SDModelKitTests: XCTestCase {
    func testMacro() throws {
        #if canImport(SDModelKitMacros)
        assertMacroExpansion(
            """
            @DomainModel
            struct User {
                let id: UUID
                @UseRelationship(.unique) var name: String
            }
            """,
            expandedSource: """
            struct User {
                let id: UUID
                var name: String
            }
            
            @Model
            final class UserPO: DataModel {
                typealias DomainModelType = User
                @Attribute(.unique) var id: UUID
                @SwiftData.Relationship(.unique) var name: String
            
                init(from domainModel: User) {
                    self.id = domainModel.id
                    self.name = domainModel.name
                }
            }

            extension User: DomainModel {
                typealias DataModelType = UserPO
            
                init(from dataModel: UserPO) {
                    self.id = dataModel.id
                    self.name = dataModel.name
                }
            }

            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
