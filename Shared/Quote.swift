import Foundation

struct Quote: Codable, Hashable {
    let text: String
    let tags: [String]
}

// Loads Quotes.json once (bundled as a resource in both the app and widget
// extension targets, same as any other Shared file). Type it in yourself —
// this is just the plumbing.
enum QuoteLibrary {
    static let all: [Quote] = {
        guard let url = Bundle.main.url(forResource: "Quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            return []
        }
        return quotes
    }()

    // Falls back to the full list if nothing matches the tag (e.g. a
    // character's quoteTag doesn't have any authored quotes yet), so the
    // Island always has something to show instead of going blank.
    static func quotes(forTag tag: String) -> [Quote] {
        let matches = all.filter { $0.tags.contains(tag) }
        return matches.isEmpty ? all : matches
    }
}
