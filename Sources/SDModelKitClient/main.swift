import SDModelKit
import SwiftData


@DomainModel
struct User {
    let id: Int
    
    @UseRelationship(deleteRule: .cascade)
    var name: String
}
