# Structure of a directory as XML in SwiftUI

<p align="center">
<img width="128" src="Images/Appicon-128.png">
</p>


## Description

This macOS SwiftUI application retrieves the structure of a directory, including files and subfolders recursively, outputting the result in XML format.

## Main window image

[Main-window.md](Main-window.md)

## Features

- **Directory Selection**: Browse and select any folder on your Mac
- **XML Generation**: Creates a structured XML representation of the selected directory
- **Recursive Traversal**: Includes all subdirectories and their files
- **Proper Indentation**: XML output is properly indented for easy reading
- **Error Handling**: Displays user-friendly error messages for any issues

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

## Examples

Given this structure:

```
Project/
├── README.md
├── src/
│   ├── main.swift
│   └── utils/
│       ├── helper.swift
│       └── config.swift
├── tests/
│   └── test_main.swift
└── docs/
    ├── guide.md
    └── api/
        └── reference.md
```

The app generates this XML:

```xml
<root name="Project" text="Root directory">
  <folder name="docs">
    <folder name="api">
      <file name="reference.md" />
    </folder>
    <file name="guide.md" />
  </folder>
  <folder name="src">
    <folder name="utils">
      <file name="config.swift" />
      <file name="helper.swift" />
    </folder>
    <file name="main.swift" />
  </folder>
  <folder name="tests">
    <file name="test_main.swift" />
  </folder>
  <file name="README.md" />
</xml>
```

Given a directory with special characters in filenames:

```
SpecialChars/
├── report & analysis.txt
├── data<2024>.csv
├── file's copy.txt
└── "quoted".txt
```

The application generates (with proper XML escaping):

```xml
<root name="SpecialChars" text="Root directory">
  <file name="&quot;quoted&quot;.txt" />
  <file name="data&lt;2024&gt;.csv" />
  <file name="file&apos;s copy.txt" />
  <file name="report &amp; analysis.txt" />
</xml>
```

## Notes

- Empty folders are included in the output with opening and closing tags but no content
- The root directory name comes from the selected folder's name
- All paths are relative to the selected root directory
- The output is always well-formed XML (assuming no file system errors)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Building and Running

1. Open `XMLFolderStructure.xcodeproj` in Xcode
2. Select your target device (Mac)
3. Build and run the application (⌘R)

## Usage

1. Click the **Browse** button to select a folder
2. The selected directory path will appear in the text field
3. Click the **Generate XML** button to create the XML output
4. The XML structure will appear in the text area below
5. You can copy the XML text from the output area

## Appicon

Appicon based on an image of [Flaticon](https://www.flaticon.com/free-icons/files-and-folders)

## License

MIT License - See LICENSE file for details
