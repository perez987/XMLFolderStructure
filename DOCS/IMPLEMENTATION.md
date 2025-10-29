# Implementation Summary: File Metadata, Syntax Highlighting, and Progress Indicator

This document summarizes the implementation of features for the XMLFolderStructure macOS application:

1. File size and modification date metadata in XML attributes
2. Syntax highlighting for XML output display
3. Progress indicator for large directories
4. Code refactoring into modular components
5. Performance optimization for large directories

## 1. File Metadata Feature

### What Was Changed

Modified the XML generation logic to include file size and modification date as attributes on `<file>` elements.

### Implementation Details

- **File**: `XMLFolderStructure/XMLGenerator.swift`
- **Functions Modified**: `processDirectory(at:indentLevel:)`, `processDirectoryAsync(at:indentLevel:)`
- **Lines Changed**: ~10 lines per function

**Before:**

```swift
let contents = try fileManager.contentsOfDirectory(
    at: url,
    includingPropertiesForKeys: [.isDirectoryKey],
    options: [.skipsHiddenFiles]
)
// ...
xml += "\(indent)<file name=\"\(name)\" />\n"
```

**After:**
 
```swift
let contents = try fileManager.contentsOfDirectory(
    at: url,
    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
    options: [.skipsHiddenFiles]
)
// ...
let fileSize = resourceValues.fileSize ?? 0
let formattedSize = formatFileSize(fileSize)

let modificationDate = resourceValues.contentModificationDate ?? Date()
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "d/M/yyyy"
let formattedDate = dateFormatter.string(from: modificationDate)

xml += "\(indent)<file name=\"\(name)\" size=\"\(formattedSize)\" modified=\"\(formattedDate)\" />\n"
```

### Result

XML output now includes:

```xml
<file name="README.md" size="1.024" modified="18/10/2024" />
```

## 2. Syntax Highlighting Feature

### What Was Changed

Replaced the plain TextEditor with a custom syntax-highlighted view that displays XML with color-coded elements. Refactored syntax highlighting logic into a separate class.

### Implementation Details

- **Files**: `XMLFolderStructure/ContentView.swift`, `XMLFolderStructure/XMLSyntaxHighlighter.swift`
- **New Class**: `XMLSyntaxHighlighter` (separate file)
- **New Functions**: `SyntaxHighlightedTextView` struct in ContentView.swift

### Components Added

**1. State Variable for Highlighted XML**

```swift
@State private var highlightedXML: NSAttributedString = NSAttributedString()
```

**2. XML Syntax Highlighter Class**

Implemented in `XMLFolderStructure/XMLSyntaxHighlighter.swift`:

```swift
class XMLSyntaxHighlighter {    
    /// Applies syntax highlighting to XML text
    /// - Parameter xml: The XML string to highlight
    /// - Returns: An NSAttributedString with color-coded XML elements
    static func highlight(_ xml: String) -> NSAttributedString {
			// Creates NSAttributedString with color-coded elements
			// Uses NSRegularExpression to identify:
			// - Tag names: <root, <folder, <file (green)
			// - Attribute names: name, size, modified (purple)
			// - Attribute values: "..." (blue)
			// - XML syntax: <, >, /, = (gray)
        let attributedString = NSMutableAttributedString(string: xml)
        let fullRange = NSRange(location: 0, length: xml.utf16.count)
        
        // Base font and color
//        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let font = NSFont.systemFont(ofSize: 12)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        
            // Private helper methods:
			// - highlightTags(in:range:text:)
			// - highlightAttributes(in:range:text:)
			// - highlightAttributeValues(in:range:text:)
			// - highlightBrackets(in:range:text:)

        // Apply syntax highlighting in order
        highlightTags(in: attributedString, range: fullRange, text: xml)
        highlightAttributes(in: attributedString, range: fullRange, text: xml)
        highlightAttributeValues(in: attributedString, range: fullRange, text: xml)
        highlightBrackets(in: attributedString, range: fullRange, text: xml)
```

**3. Custom SwiftUI View Wrapper**

```swift
struct SyntaxHighlightedTextView: NSViewRepresentable {
    // Wraps NSTextView for displaying attributed text in SwiftUI
    // Configures text view as non-editable but selectable
    // Updates display when attributedString binding changes
}
```

**4. UI Update**

```swift
// Before:
TextEditor(text: $xmlOutput)
    .font(.system(.body, design: .default))

// After:
SyntaxHighlightedTextView(attributedString: $highlightedXML)
```

**5. Generation Update**

```swift
private func performGenerateXML() {
    // ...
    xmlOutput = try await xmlGenerator.buildXMLAsync(for: directory)
    
    // Apply syntax highlighting conditionally based on directory size
    if useSyntaxHighlighting {
        highlightedXML = XMLSyntaxHighlighter.highlight(xmlOutput)
    } else {
        // Plain text for large directories
        highlightedXML = NSAttributedString(string: xmlOutput, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.textColor
        ])
    }
    // ...
}
```

### Color Scheme

| Element | Color | Example |
|---------|-------|---------|
| Tag Names | Green (`NSColor.systemGreen`) | `<root`, `<file` |
| Attribute Names | Purple (`NSColor.systemPurple`) | `name`, `size` |
| Attribute Values | Blue (`NSColor.systemBlue`) | `"README.md"`, `"1024"` |
| XML Syntax | Gray (`NSColor.systemGray`) | `<`, `>`, `/` |

## 3. Key Design Decisions

### 1. Metadata Format

- **Size**: Displayed in bytes with dot separators (e.g., 1.024, 1.234.567) for readability
- **Date Format**: "d/M/yyyy" for consistent formatting (e.g., 18/10/2024)
- **Default Values**: 0 for size, current date for modification if unavailable
- **Number Formatting**: Uses NumberFormatter with explicit locale settings for consistent thousand separators

#### 2. Syntax Highlighting

- **Regular Expressions**: Used for pattern matching XML elements
- **NSAttributedString**: Chosen for rich text formatting
- **System Colors**: Use macOS system colors for automatic light/dark mode support
- **Monospaced Font**: Maintains consistent character alignment
- **Read-Only Display**: Prevents accidental editing while allowing text selection

#### 3. Backward Compatibility

- Plain XML (without colors) is exported/copied for compatibility
- Export and clipboard functions use the original `xmlOutput` string
- Syntax highlighting is only for visual display within the app

#### 4. Code Organization

- **XMLGenerator.swift**: Encapsulates all XML generation logic
- **XMLSyntaxHighlighter.swift**: Handles syntax highlighting separately
- **ContentView.swift**: Manages UI and coordinates between components
- **Separation of Concerns**: Business logic separated from UI presentation

## 4. Progress Indicator Feature

Added a progress indicator that displays during XML generation for large directories, showing both a progress bar and item count.

### Implementation Details

- **Files**: `XMLFolderStructure/ContentView.swift`, `XMLFolderStructure/XMLGenerator.swift`
- **New Functions in XMLGenerator**: `countItems(at:)`, `buildXMLAsync(for:)`, `processDirectoryAsync(at:indentLevel:)`
- **Functions Modified in ContentView**: `generateXML()`, `performGenerateXML()`
- **Localization**: Added "Processing:" and "items" strings to English and Spanish

#### Components Added

**1. State Variables for Progress Tracking**

In ContentView.swift:

```swift
@State private var isGenerating: Bool = false
@State private var progressValue: Double = 0.0
@State private var totalItems: Int = 0
@State private var processedItems: Int = 0
```

In XMLGenerator.swift:

```swift
// Progress tracking callback
var onProgressUpdate: ((Int, Double) -> Void)?

private var totalItems: Int = 0
private var processedItems: Int = 0
```

**2. Progress UI Component**

```swift
if isGenerating {
    VStack(spacing: 5) {
        ProgressView(value: progressValue, total: 1.0)
            .progressViewStyle(.linear)
            .frame(maxWidth: 400)
        Text("Processing: \(processedItems) / \(totalItems) items")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

**3. Item Counting Function**

In XMLGenerator.swift:

```swift
func countItems(at url: URL) -> Int {
    // Uses FileManager.enumerator for efficient counting
    // Skips hidden files
    // Returns total count for progress calculation
}
```

**4. Asynchronous Generation with Progress**

In ContentView.swift:

```swift
private func performGenerateXML() {
    guard let directory = selectedDirectory else { return }
    
    // Reset progress state
    isGenerating = true
    progressValue = 0.0
    processedItems = 0
    xmlOutput = ""
    highlightedXML = NSAttributedString()
    
    // Set up progress callback
    xmlGenerator.onProgressUpdate = { processed, progress in
        Task { @MainActor in
            self.processedItems = processed
            self.progressValue = progress
        }
    }
    
    // Run asynchronously in Task
    Task {
        // Count total items first
        await MainActor.run {
            totalItems = directoryItemCount
        }
        
        // Generate XML with progress updates
        let xml = try await xmlGenerator.buildXMLAsync(for: directory)
        
        // Update UI on main thread
        await MainActor.run {
            xmlOutput = xml
            if useSyntaxHighlighting {
                highlightedXML = XMLSyntaxHighlighter.highlight(xml)
            } else {
                highlightedXML = NSAttributedString(string: xml, attributes: [...])
            }
            isGenerating = false
        }
    }
}
```

**5. Async Processing Functions**

In XMLGenerator.swift:

- `buildXMLAsync(for:)`: Async version of buildXML, manages total item counting
- `processDirectoryAsync(at:indentLevel:)`: Async version with progress updates via callback

```swift
// Update progress after each item in processDirectoryAsync
processedItems += 1
let progress = totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0.0
onProgressUpdate?(processedItems, progress)
```

### Key Design Decisions

##### Asynchronous Processing

- Uses Swift's async/await for non-blocking execution
- Wraps in Task for proper async context
- Updates UI on MainActor to ensure thread safety

##### Progress Calculation

- Pre-counts all items before processing for accurate progress
- Updates after each file/folder processed
- Calculates percentage: `processedItems / totalItems`

##### UI Updates

- Progress bar uses linear style for simplicity
- Shows both visual (progress bar) and numeric (X / Y items) feedback
- Disables Generate button during processing
- Hides progress UI when not generating

##### Performance

- Counting pass is faster (no XML generation)
- Progress updates happen on main thread but are minimal via callback pattern
- Original synchronous functions kept for compatibility
- Callback pattern separates concerns between XMLGenerator and UI

## 5. Performance Optimization for Large Directories

Added conditional syntax highlighting and warning dialog for directories with more than 10,000 items to prevent application freezing.

### Implementation Details

- **Files**: `XMLFolderStructure/ContentView.swift`, `XMLFolderStructure/XMLGenerator.swift`
- **New Functions**: `calculateDirectorySize(at:)` in XMLGenerator, `showWarningAlertWithIcon()` in ContentView
- **State Variables Added**: `directoryItemCount`, `directorySize`, `useSyntaxHighlighting`
- **Localization**: Added warning dialog strings to English and Spanish

### Components Added

**1. Directory Size Calculation**

In XMLGenerator.swift:

```swift
func calculateDirectorySize(at url: URL) -> Int64 {
    // Calculates total size of all files in directory
    // Uses FileManager.enumerator for efficient traversal
    // Returns total size in bytes
    // Skips hidden files
}
```

**2. State Variables for Performance Management**

In ContentView.swift:

```swift
@State private var directoryItemCount: Int = 0
@State private var directorySize: Int64 = 0
@State private var useSyntaxHighlighting: Bool = true
```

**3. Pre-Generation Analysis**

In ContentView.swift:

```swift
private func generateXML() {
    guard let directory = selectedDirectory else { return }
    
    // Count items and calculate size
    directoryItemCount = xmlGenerator.countItems(at: directory)
    directorySize = xmlGenerator.calculateDirectorySize(at: directory)
    
    // Determine if syntax highlighting should be used
    useSyntaxHighlighting = directoryItemCount <= 10000
    
    // Show warning if directory has more than 10,000 items
    if directoryItemCount > 10000 {
        showWarningAlertWithIcon()
    } else {
        performGenerateXML()
    }
}
```

**4. Warning Dialog**

In ContentView.swift:

```swift
    private func showWarningAlertWithIcon() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Warning:", comment: "")
        alert.informativeText = String(format: NSLocalizedString("WarningMessage:", comment: ""), directoryItemCount)
            // alertStyle = .warning has issues rendering Continue button on macOS 15+
		alert.alertStyle = .informational

			// Note: Removed SF Symbol icon as it was causing the Continue button to not render properly
			// The .warning alertStyle already provides a suitable warning icon
		if let warningImage = NSImage(systemSymbolName:  "exclamationmark.triangle", accessibilityDescription: "Warning") {
			alert.icon = warningImage
		}

        let continueButton = alert.addButton(withTitle: NSLocalizedString("Continue:", comment: ""))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel:", comment: ""))
        
			// Style the buttons to make them visible and distinguishable
        continueButton.keyEquivalent = "\r"  // Return key - makes it the default button with blue accent
        cancelButton.keyEquivalent = "\u{1b}"  // Escape key - standard cancel button

		if #available(macOS 15.0, *) {
				// Fix for macOS 15+ (Sequoia/Tahoe): Force button rendering before showing modal
				// In macOS 15+, NSAlert buttons may not render immediately after being added
				// This workaround forces the layout and display update to ensure buttons are visible
			continueButton.needsDisplay = true
			cancelButton.needsDisplay = true
				// Force the alert window to complete its layout and display pass before showing the modal
				// This ensures all UI elements, including buttons, are properly rendered
				// NSAlert.window is always available as alerts create their window on initialization
			alert.window.contentView?.layoutSubtreeIfNeeded()
			alert.window.displayIfNeeded()
		}

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
				// Continue button clicked
            performGenerateXML()
        }
        // If cancel or closed, do nothing
    }```

**5. Conditional Syntax Highlighting**

In ContentView.swift (within performGenerateXML):

```swift
// Apply syntax highlighting only if directory has <= 10,000 items
if useSyntaxHighlighting {
    highlightedXML = XMLSyntaxHighlighter.highlight(xml)
} else {
    // Use plain text without syntax highlighting for large directories
    let plainText = NSAttributedString(string: xml, attributes: [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.textColor
    ])
    highlightedXML = plainText
}
```

### Key Design Decisions

##### Performance Threshold

- **10,000 items**: Chosen as the threshold based on testing
- Syntax highlighting with regex operations becomes slow beyond this threshold
- Warning allows user to make informed decision

##### User Experience

- Non-blocking: User can cancel the operation
- Informative: Dialog explains why syntax highlighting is disabled
- Transparent: User knows what to expect before generation starts

##### Fallback Behavior

- Plain text display maintains readability
- Export and copy functions unaffected
- All XML functionality remains available

##### Performance

- Counting pass is faster (no XML generation)
