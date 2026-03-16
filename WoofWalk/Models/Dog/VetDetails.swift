import Foundation

struct VetDetails: Codable, Equatable {
    var practiceName: String
    var vetName: String
    var phone: String
    var address: String

    init(practiceName: String = "", vetName: String = "", phone: String = "", address: String = "") {
        self.practiceName = practiceName; self.vetName = vetName; self.phone = phone; self.address = address
    }
}
