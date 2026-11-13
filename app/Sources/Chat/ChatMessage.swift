import Foundation

// One entry of the conversation: a user bubble, an assistant answer or an error line.
struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user, assistant, error
    }

    let id: UUID
    let role: Role
    var text: String
    var images: [ImageAttachment]
    var cost: TurnCost?
    let date: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        images: [ImageAttachment] = [],
        cost: TurnCost? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.images = images
        self.cost = cost
        self.date = date
    }
}
