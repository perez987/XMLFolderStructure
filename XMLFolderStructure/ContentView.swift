import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedDirectory: URL?
    @State private var xmlOutput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var highlightedXML: NSAttributedString = NSAttributedString()
    
    var body: some View {
        VStack(spacing: 20) {
            // Top section: Directory selection
            VStack(spacing: 10) {
                HStack {
                    Text(NSLocalizedString("Selected directory:", comment: ""))
//                        .frame(width: 130, alignment: .leading)

                    TextField(NSLocalizedString("No directory selected:", comment: ""), text: .constant(selectedDirectory?.path ?? NSLocalizedString("No directory selected:", comment: "")))
                        .disabled(true)

                    Button(NSLocalizedString("Browse:", comment: "")) {
                        selectDirectory()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                Button(NSLocalizedString("Generate XML:", comment: "")) {
                    generateXML()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDirectory == nil)
            }
            .padding(.top)
            
            Divider()
            
            // Bottom section: XML output area
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("XML Output:", comment: ""))
                    .font(.headline)

                    SyntaxHighlightedTextView(attributedString: $highlightedXML)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Export and clipboard buttons
                HStack(spacing: 10) {
                    Spacer()
                    Button(NSLocalizedString("Export to File:", comment: "")) {
                        exportToFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(xmlOutput.isEmpty)
                    Spacer()
                    Button(NSLocalizedString("Copy to Clipboard:", comment: "")) {
                        copyToClipboard()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(xmlOutput.isEmpty)
                    Spacer()
                }
            }
            .padding(26)
//            .padding(.horizontal)
//            .padding(.bottom)
        }
        .frame(minWidth: 700, minHeight: 600)
        
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Directory Selection
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        
        panel.begin { response in
            if response == .OK {
                selectedDirectory = panel.url
                xmlOutput = ""
            }
        }
    }
    
    // MARK: - XML Generation
    
    private func generateXML() {
        guard let directory = selectedDirectory else {
            showErrorMessage("No directory selected")
            return
        }
        
        do {
            xmlOutput = try buildXML(for: directory)
            highlightedXML = XMLSyntaxHighlighter.highlight(xmlOutput)
        } catch {
            showErrorMessage("Error generating XML: \(error.localizedDescription)")
        }
    }
    
    private func xmlEscape(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let locale: Locale = Locale(identifier: "en")
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true
        formatter.hasThousandSeparators = true
        return formatter.string(from: NSNumber(value: size)) ?? "\(size)"
    }
    
    private func buildXML(for url: URL) throws -> String {
        var xml = ""
        let directoryName = xmlEscape(url.lastPathComponent)
        
        // Root directory opening tag
        xml += "<root name=\"\(directoryName)\" text=\"Root directory\">\n"
        
        // Process directory contents recursively
        xml += try processDirectory(at: url, indentLevel: 1)
        
        // Closing tag
        xml += "</root>\n"
        
        return xml
    }
    
    private func processDirectory(at url: URL, indentLevel: Int) throws -> String {
        var xml = ""
        let fileManager = FileManager.default
        let indent = String(repeating: "  ", count: indentLevel)
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Sort contents: directories first, then files, both alphabetically
            let sortedContents = contents.sorted { url1, url2 in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                
                if isDir1 != isDir2 {
                    return isDir1
                }
                return url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
            }
            
            for item in sortedContents {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let name = xmlEscape(item.lastPathComponent)
                
                if isDirectory {
                    // Folder tag
                    xml += "\(indent)<folder name=\"\(name)\">\n"
                    
                    // Recursively process subdirectory
                    xml += try processDirectory(at: item, indentLevel: indentLevel + 1)
                    
                    // Close folder tag
                    xml += "\(indent)</folder>\n"
                } else {
                    // File tag with size and date attributes
                    let fileSize = (resourceValues.fileSize) ?? 0
                    let formattedSize = formatFileSize(fileSize)
                    
                    let modificationDate = resourceValues.contentModificationDate ?? Date()
                    let dateFormatter = DateFormatter()
//                    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    dateFormatter.dateFormat = "d/M/yyyy"
                    let formattedDate = dateFormatter.string(from: modificationDate)
                    
                    xml += "\(indent)<file name=\"\(name)\" size=\"\(formattedSize)\" modified=\"\(formattedDate)\" />\n"
                }
            }
        } catch {
            throw NSError(
                domain: "XMLFolderStructure",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read directory at \(url.path): \(error.localizedDescription)"]
            )
        }
        
        return xml
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Export and Clipboard
    
    private func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "folder_structure.xml"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try xmlOutput.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    showErrorMessage("Failed to save file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(xmlOutput, forType: .string)
    }
}

// MARK: - Custom Syntax Highlighted Text View

struct SyntaxHighlightedTextView: NSViewRepresentable {
    @Binding var attributedString: NSAttributedString
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedString)
    }
}

#Preview {
    ContentView()
}
