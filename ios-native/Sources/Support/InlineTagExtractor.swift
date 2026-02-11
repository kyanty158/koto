import Foundation

enum InlineTagExtractor {
    private static let regex = try! NSRegularExpression(pattern: "(^|\\s)#([A-Za-z0-9_\\-]+)")

    static func extract(from text: String) -> [String] {
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var set = Set<String>()
        for match in matches {
            if match.numberOfRanges >= 3 {
                let range = match.range(at: 2)
                if range.location != NSNotFound {
                    let tag = nsText.substring(with: range).lowercased()
                    if !tag.isEmpty {
                        set.insert(tag)
                    }
                }
            }
        }
        return Array(set).sorted()
    }
}
