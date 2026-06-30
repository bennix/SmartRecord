import Foundation

nonisolated struct SmartFocusRecordingLog: Codable {
    var clicks: [SmartFocusClickRecord]
    var samples: [SmartFocusCursorRecord]

    init(clicks: [SmartFocusClickRecord] = [], samples: [SmartFocusCursorRecord] = []) {
        self.clicks = clicks
        self.samples = samples
    }

    private enum CodingKeys: String, CodingKey {
        case clicks
        case samples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clicks = try container.decodeIfPresent([SmartFocusClickRecord].self, forKey: .clicks) ?? []
        self.samples = try container.decodeIfPresent([SmartFocusCursorRecord].self, forKey: .samples) ?? []
    }
}

nonisolated struct SmartFocusClickRecord: Codable {
    var time: Double
    var nx: Double
    var ny: Double
}

nonisolated struct SmartFocusCursorRecord: Codable {
    var time: Double
    var nx: Double
    var ny: Double
    var dragging: Bool
}
