import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedDirectory: URL?
    @State private var xmlOutput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
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

                    TextEditor(text: $xmlOutput)
                        .font(.system(.body, design: .default))
//						.scrollContentBackground(.hidden)
//						.background(Color.Navy)
//						.foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                includingPropertiesForKeys: [.isDirectoryKey],
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
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
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
                    // File tag
                    xml += "\(indent)<file name=\"\(name)\" />\n"
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
}

#Preview {
    ContentView()
}
