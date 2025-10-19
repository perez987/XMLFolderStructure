# XMLFolderStructure Application Documentation

## Overview

This macOS SwiftUI application provides a graphical interface to generate XML representations of directory structures.

## Project Structure

```
XMLFolderStructure/
├── XMLFolderStructure.xcodeproj/       # Xcode project file
│   └── project.pbxproj                 # Project configuration
├── XMLFolderStructure/                 # Source code directory
│   ├── XMLFolderStructureApp.swift     # Main app entry point
│   ├── ContentView.swift               # Main UI and logic
│   ├── XMLSyntaxHighlighter.swift      # XML text syntax highlight
│   ├── XMLFolderStructure.entitlements # App permissions (file access)
│   ├── Assets.xcassets/                # App icons and colors
│   └── Preview Content/                # Preview assets for SwiftUI
├── README.md                           # User documentation
└── LICENSE                             # MIT License
```

## Core Components

### XMLFolderStructureApp.swift

- Main application entry point
- Defines the app lifecycle using SwiftUI's `@main` attribute
- Creates the main window with ContentView

### ContentView.swift

The main view containing all UI and business logic, including the SyntaxHighlightedTextView component:

#### UI Elements

1. **Directory Selection Section** (Top)
   - Label: "Selected Directory:"
   - TextField: Displays selected directory path (read-only)
   - Browse Button: Opens folder picker dialog
   - Generate XML Button: Triggers XML generation (disabled until directory selected)

2. **XML Output Section** (Bottom)
   - Label: "XML Output:"
   - SyntaxHighlightedTextView: Displays generated XML with color-coded syntax highlighting
     - Green: Tag names (root, folder, file)
     - Purple: Attribute names (name, size, modified, text)
     - Blue: Attribute values (in quotes)
     - Gray: XML brackets and slashes
   - ScrollView: Allows scrolling through long XML output
   - ProgressView: Linear progress bar displayed during XML generation (only visible when generating)
   - Progress Text: Shows "Processing: X / Y items" below the progress bar
   - Export to File Button: Opens save dialog to export XML to a file (disabled when no XML)
   - Copy to Clipboard Button: Copies XML to system clipboard (disabled when no XML)

#### State Management

- `selectedDirectory`: Stores the URL of the selected directory
- `xmlOutput`: Contains the generated XML string (plain text for export/clipboard)
- `highlightedXML`: Contains the syntax-highlighted attributed string for display
- `errorMessage`: Holds error messages for display
- `showError`: Controls error alert visibility
- `isGenerating`: Indicates whether XML generation is in progress
- `progressValue`: Stores the progress percentage (0.0 to 1.0) for the progress bar
- `totalItems`: Total count of items (files and folders) to process
- `processedItems`: Count of items processed so far

#### Key Functions

##### countItems(at:)

- Counts the total number of files and folders in a directory recursively
- Uses FileManager's enumerator for efficient traversal
- Returns the total count for progress tracking
- Skips hidden files (files starting with ".")

##### generateXML()

- Entry point for XML generation
- Guards against nil directory
- Resets progress state and clears previous output
- Runs XML generation asynchronously in a Task
- Counts total items before processing
- Calls buildXMLAsync() for actual generation
- Updates UI on main thread when complete
- Handles errors and displays error messages
- Disables the Generate button during processing

##### buildXML(for:)

- Synchronous XML building function (kept for compatibility)
- Creates root tag with directory name
- Calls processDirectory() recursively
- Returns complete XML string

##### buildXMLAsync(for:)

- Asynchronous version of buildXML
- Creates root tag with directory name
- Calls processDirectoryAsync() recursively with progress tracking
- Returns complete XML string

##### processDirectory(at:indentLevel:)

- Synchronously processes directory contents (kept for compatibility)
- Recursively processes directory contents
- Fetches file metadata (size, modification date) for each item
- Sorts items: folders first, then files (alphabetically)
- Generates appropriate XML tags:
  - `<folder name="...">` for directories
  - `<file name="..." size="..." modified="..." />` for files with metadata
- Maintains proper indentation based on nesting level
- Handles file system errors

##### processDirectoryAsync(at:indentLevel:)

- Asynchronous version with progress tracking
- Recursively processes directory contents
- Fetches file metadata (size, modification date) for each item
- Sorts items: folders first, then files (alphabetically)
- Generates appropriate XML tags:
  - `<folder name="...">` for directories
  - `<file name="..." size="..." modified="..." />` for files with metadata
- Maintains proper indentation based on nesting level
- Updates progress after processing each item on MainActor
- Handles file system errors

##### formatFileSize(_:)

Added a `formatFileSize(_:)` helper function in `ContentView.swift` that uses `NumberFormatter` to format file sizes with dots as thousands separators:

```swift
private func formatFileSize(_ size: Int) -> String {
    let locale: Locale = Locale(identifier: "en")
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.groupingSize = 3
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: size)) ?? "\(size)"
}
```

The function is applied to all file size values in the XML generation, converting raw byte counts into readable formatted strings.

- Formats file sizes with thousands separators for better readability
- Explicitly sets the locale to ensure consistent behavior across all macOS versions
- Explicitly enables grouping separator to ensure it's applied to all numbers
- Examples: 1024 → 1.024, 1234567 → 1.234.567
- Numbers below 1000 remain unchanged (e.g., 512 → 512)

##### highlightXMLSyntax(_:)

- Applies syntax highlighting to XML output
- Uses NSAttributedString for rich text formatting
- Color codes different XML elements:
  - Tag names in green (systemGreen)
  - Attribute names in purple (systemPurple)
  - Attribute values in blue (systemBlue)
  - Brackets and slashes in gray (systemGray)
- Uses monospaced font for consistent formatting
- Returns NSAttributedString for display

##### exportToFile()

- Creates and configures NSSavePanel for file export
- Sets default filename to "folder_structure.xml"
- Allows user to choose save location
- Writes XML output to selected file location
- Displays error message if save fails

##### copyToClipboard()

- Clears system clipboard
- Copies XML output to clipboard using NSPasteboard
- Allows easy pasting into other applications

### SyntaxHighlightedTextView

A custom SwiftUI view component that wraps NSTextView for displaying attributed text:

#### Implementation

- Conforms to NSViewRepresentable protocol
- Creates a scrollable NSTextView instance
- Configures text view properties:
  - Non-editable but selectable
  - Disables automatic text substitution features
  - Uses system text background color
- Updates content when attributed string binding changes

#### Usage

- Takes a binding to NSAttributedString
- Automatically displays syntax-highlighted XML
- Provides native macOS text view experience with scrolling

## Features

### Directory Traversal

- Recursively scans all subdirectories
- Skips hidden files (files starting with ".")
- Handles nested folder structures of any depth

### Sorting

- Directories listed before files at each level
- Alphabetical sorting within each category
- Uses localized string comparison for natural ordering

### Error Handling

- File system access errors
- Invalid directory paths
- Permission denied scenarios
- User-friendly error messages via SwiftUI alerts

### Security

- Uses App Sandbox with appropriate entitlements
- Requires user selection of directories (no arbitrary file access)
- Read-only access to selected directories

## Entitlements

The app requires the following entitlements (defined in XMLFolderStructure.entitlements):

- `com.apple.security.app-sandbox`: Enables App Sandbox
- `com.apple.security.files.user-selected.read-only`: Allows reading user-selected files/folders

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later

## Building

1. Open XMLFolderStructure.xcodeproj in Xcode
2. Select a Mac as the target device
3. Build: Product > Build (⌘B)
4. Run: Product > Run (⌘R)

## Implemented Enhancements

Recent additions to the application:

- ✅ **File size and metadata in XML attributes**: Each file tag now includes size (in bytes) and modification date attributes
- ✅ **Syntax highlighting for XML output**: The XML display now features color-coded syntax highlighting for improved readability
- ✅ **Progress indicator for large directories**: Real-time progress bar and item counter displayed during XML generation

## Future Enhancements

Potential improvements for future versions:

- XML validation
- Configurable file filters
- Optional inclusion of hidden files
