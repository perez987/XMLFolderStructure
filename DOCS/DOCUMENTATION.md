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
The main view containing all UI and business logic:

#### UI Elements
1. **Directory Selection Section** (Top)
   - Label: "Selected Directory:"
   - TextField: Displays selected directory path (read-only)
   - Browse Button: Opens folder picker dialog
   - Generate XML Button: Triggers XML generation (disabled until directory selected)

2. **XML Output Section** (Bottom)
   - Label: "XML Output:"
   - TextEditor: Displays generated XML in monospaced font
   - ScrollView: Allows scrolling through long XML output

#### State Management
- `selectedDirectory`: Stores the URL of the selected directory
- `xmlOutput`: Contains the generated XML string
- `errorMessage`: Holds error messages for display
- `showError`: Controls error alert visibility

#### Key Functions

##### selectDirectory()
- Creates and configures NSOpenPanel for folder selection
- Updates `selectedDirectory` on successful selection
- Clears previous XML output

##### generateXML()
- Entry point for XML generation
- Guards against nil directory
- Handles errors and displays error messages

##### buildXML(for:)
- Main XML building function
- Creates root tag with directory name
- Calls processDirectory() recursively
- Returns complete XML string

##### processDirectory(at:indentLevel:)
- Recursively processes directory contents
- Sorts items: folders first, then files (alphabetically)
- Generates appropriate XML tags:
  - `<folder name="...">` for directories
  - `<file name="..." />` for files
- Maintains proper indentation based on nesting level
- Handles file system errors

## XML Output Format

```xml
<root name="directory_name" text="Root directory">
  <folder name="subfolder1">
    <file name="file1.txt" />
    <file name="file2.txt" />
    <folder name="nested_folder">
      <file name="nested_file.txt" />
    </folder>
  </folder>
  <file name="root_file.txt" />
</xml>
```

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

## Usage Flow

1. User launches the application
2. Main window appears with empty directory field and disabled XML button
3. User clicks "Browse" button
4. Folder selection dialog appears
5. User selects a directory and clicks "Open"
6. Selected path appears in the text field
7. "Generate XML" button becomes enabled
8. User clicks "Generate XML"
9. Application recursively scans directory
10. XML output appears in the text editor below
11. User can copy the XML text for use elsewhere

## Testing

The core XML generation logic can be tested independently:
- Create test directory structures
- Run Swift scripts with the XML generation functions
- Verify output format and error handling
- Test with special characters and nested structures

## Future Enhancements

Potential improvements for future versions:
- Export XML to file
- Copy to clipboard button
- XML validation
- Configurable file filters
- Optional inclusion of hidden files
- File size and metadata in XML attributes
- Progress indicator for large directories
- Syntax highlighting for XML output
