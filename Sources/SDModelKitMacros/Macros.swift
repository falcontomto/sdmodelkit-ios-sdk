import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct DomainModelMacro: PeerMacro, ExtensionMacro {
    public enum MacroError: Error {
        case structExpected
    }
    
    private static func assertStruct(_ declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> StructDeclSyntax {
        guard let structDecl = declaration.as(StructDeclSyntax.self)
        else {
            context.diagnose(Diagnostic(node: declaration, message: MacroExpansionErrorMessage("Should be attached to a struct")))
            throw MacroError.structExpected
        }
        
        return structDecl
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let structDecl = try assertStruct(declaration, in: context)
        
        func remap(_ varDecl: VariableDeclSyntax) throws -> VariableDeclSyntax {
            if let binding = varDecl.bindings.first,
               let ident = binding.pattern.as(IdentifierPatternSyntax.self),
               ident.identifier.text == "id",
               let type = binding.typeAnnotation?.type.description {
                return try VariableDeclSyntax("@Attribute(.unique) var id: \(raw: type)")
            }
            
            let attrs = varDecl.attributes
            guard !attrs.isEmpty else { return varDecl }
            
            let newAttrs = AttributeListSyntax(attrs.map { element in
                guard case .attribute(let attr) = element else { return element }
                
                // Matches `@UseRelationship(...)` (unqualified).
                let rawName = attr.attributeName.trimmedDescription
                guard rawName == "UseRelationship" else { return element }
                
                // Rewrite to `@SwiftData.Relationship(...)` while preserving arguments.
                var rewritten = attr
                rewritten.attributeName = TypeSyntax(stringLiteral: "SwiftData.Relationship")
                return .attribute(rewritten)
            })
            
            return varDecl.with(\.attributes, newAttrs)
        }
        
        let structName = structDecl.name.text
        
        // Extract backing type: @DomainModel(backing: UserPO)
        let backingName = "\(structName)PO"
        
        // Collect stored properties
        let members = try structDecl.memberBlock.members.compactMap { member -> VariableDeclSyntax? in
            guard var varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            
            // Keep only stored properties (no accessor block).
            let storedBindings = varDecl.bindings.filter { $0.accessorBlock == nil }
            guard !storedBindings.isEmpty else { return nil }
            
            varDecl = varDecl.with(\.bindings, storedBindings)
            varDecl = try remap(varDecl)
            
            return varDecl
        }
        
        let memberLines = members
            .map { $0.trimmedDescription }
            .joined(separator: "\n")
        let domainInitLines = members
            .flatMap {
                $0.bindings.compactMap {
                    $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                }
            }
            .map { "self.\($0) = domainModel.\($0)" }
            .joined(separator: "\n")
        
        let poDecl: DeclSyntax = """
        @Model
        final class \(raw: backingName): DataModel {
            typealias DomainModelType = \(raw: structName)
            \(raw: memberLines)
        
            init(from domainModel: \(raw: structName)) {
                \(raw: domainInitLines)
            }
        }
        """
        
        return [poDecl]
    }
    
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let structDecl = try assertStruct(declaration, in: context)
        
        let structName = structDecl.name.text
        let modifiers = structDecl.modifiers
        
        // Extract backing type: @DomainModel(backing: UserPO)
        let backingName = "\(structName)PO"
        
        // Collect stored properties
        let properties: [(String, String)] = structDecl.memberBlock.members.compactMap { member -> (String, String)? in
            guard
                let varDecl = member.decl.as(VariableDeclSyntax.self),
                let binding = varDecl.bindings.first,
                let ident = binding.pattern.as(IdentifierPatternSyntax.self),
                let type = binding.typeAnnotation?.type
            else { return nil }
            
            return (ident.identifier.text, type.description.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Build init(from dataModel:)
        let dataInitLines = properties
            .map { "self.\($0.0) = dataModel.\($0.0)" }
            .joined(separator: "\n        ")
        
        let extensionDecl: DeclSyntax = """
        \(raw: modifiers)extension \(raw: structName): DomainModel {
            typealias DataModelType = \(raw: backingName)
        
            init(from dataModel: \(raw: backingName)) {
                \(raw: dataInitLines)
            }
        }
        """
        
        return [extensionDecl.as(ExtensionDeclSyntax.self)!]
    }
}

public struct InertAttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // No accessors added → no behavior change.
        return []
    }
}


@main
struct ModelMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DomainModelMacro.self,
        InertAttributeMacro.self
    ]
}
