// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftData

@attached(peer, names: suffixed(PO))
@attached(extension, names: named(DataModelType), named(init(from:)), conformances: DomainModel)
public macro DomainModel() = #externalMacro(
    module: "SDModelKitMacros",
    type: "DomainModelMacro"
)

@attached(peer)
public macro UseRelationship(
    _ options: SwiftData.Schema.Relationship.Option...,
    deleteRule: SwiftData.Schema.Relationship.DeleteRule = .nullify,
    minimumModelCount: Int? = 0,
    maximumModelCount: Int? = 0,
    originalName: String? = nil,
    inverse: AnyKeyPath? = nil,
    hashModifier: String? = nil
) = #externalMacro(
    module: "SDModelKitMacros",
    type: "InertAttributeMacro"
)

