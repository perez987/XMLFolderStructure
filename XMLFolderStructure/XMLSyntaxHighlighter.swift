import AppKit

/// A class responsible for applying syntax highlighting to XML text
class XMLSyntaxHighlighter {
    
    // MARK: - Public Methods
    
    /// Applies syntax highlighting to XML text
    /// - Parameter xml: The XML string to highlight
    /// - Returns: An NSAttributedString with color-coded XML elements
    static func highlight(_ xml: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: xml)
        let fullRange = NSRange(location: 0, length: xml.utf16.count)
        
        // Base font and color
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        
        // Apply syntax highlighting in order
        highlightTags(in: attributedString, range: fullRange, text: xml)
        highlightAttributes(in: attributedString, range: fullRange, text: xml)
        highlightAttributeValues(in: attributedString, range: fullRange, text: xml)
        highlightBrackets(in: attributedString, range: fullRange, text: xml)
        
        return attributedString
    }
    
    // MARK: - Private Methods
    
    /// Highlights XML tag names (opening and closing tags)
    private static func highlightTags(in attributedString: NSMutableAttributedString, range: NSRange, text: String) {
        let tagPattern = "</?[a-zA-Z][a-zA-Z0-9]*"
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let matches = tagRegex.matches(in: text, options: [], range: range)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
            }
        }
    }
    
    /// Highlights XML attribute names
    private static func highlightAttributes(in attributedString: NSMutableAttributedString, range: NSRange, text: String) {
        let attributePattern = "\\s([a-zA-Z][a-zA-Z0-9]*)="
        if let attrRegex = try? NSRegularExpression(pattern: attributePattern, options: []) {
            let matches = attrRegex.matches(in: text, options: [], range: range)
            for match in matches {
                if match.numberOfRanges > 1 {
                    let attrNameRange = match.range(at: 1)
                    attributedString.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: attrNameRange)
                }
            }
        }
    }
    
    /// Highlights XML attribute values (in quotes)
    private static func highlightAttributeValues(in attributedString: NSMutableAttributedString, range: NSRange, text: String) {
        let valuePattern = "\"[^\"]*\""
        if let valueRegex = try? NSRegularExpression(pattern: valuePattern, options: []) {
            let matches = valueRegex.matches(in: text, options: [], range: range)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
            }
        }
    }
    
    /// Highlights XML brackets and slashes
    private static func highlightBrackets(in attributedString: NSMutableAttributedString, range: NSRange, text: String) {
        let bracketPattern = "[<>/]"
        if let bracketRegex = try? NSRegularExpression(pattern: bracketPattern, options: []) {
            let matches = bracketRegex.matches(in: text, options: [], range: range)
            for match in matches {
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
            }
        }
    }
}
