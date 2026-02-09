//
//  Protocols.swift
//  ModelMacro
//
//  Created by Yat To on 06/02/2026.
//


import Foundation
import SwiftData

public protocol DomainModel: Identifiable {
    associatedtype DataModelType: DataModel where DataModelType.DomainModelType == Self
    
    init(from dataModel: DataModelType)
}

public protocol DataModel: PersistentModel, Identifiable {
    associatedtype DomainModelType: DomainModel where DomainModelType.DataModelType == Self
    
    init(from domainModel: DomainModelType)
}

