import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedDirectory: URL?
    @State private var xmlOutput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isGenerating: Bool = false
    @State private var progressValue: Double = 0.0
    @State private var totalItems: Int = 0
    @State private var processedItems: Int = 0
    
    private let xmlGenerator = XMLGenerator()
    
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
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Button(NSLocalizedString("Generate XML:", comment: "")) {
                    generateXML()
                }
                .buttonStyle(.bordered)
                .disabled(selectedDirectory == nil || isGenerating)
                
                // Progress indicator
                if isGenerating {
                    VStack(spacing: 5) {
                        ProgressView(value: progressValue, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 400)
                            // Text: Processing processed_items / total_number items
                        Text("\(NSLocalizedString("Processing:", comment: "")) \(processedItems) / \(totalItems) \(NSLocalizedString("items", comment: ""))")
                            // Text: Directory contains total_number items
//                        Text("\(NSLocalizedString("Directory contains:", comment: "")) \(totalItems) \(NSLocalizedString("items", comment: ""))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            
            Divider()
            
            // Bottom section: XML output area
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("XML Output:", comment: ""))
                    .font(.headline)

                TextEditor(text: $xmlOutput)
//                    .font(.system(.body, design: .monospaced))
                    .font(.system(.callout))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Export and clipboard buttons
                HStack(spacing: 10) {
                    Spacer()
                    Button(NSLocalizedString("Export to File:", comment: "")) {
                        exportToFile()
                    }
                    .buttonStyle(.bordered)
                    .disabled(xmlOutput.isEmpty)
                    Spacer()
                    Button(NSLocalizedString("Copy to Clipboard:", comment: "")) {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)
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
        
        // Reset progress state
        isGenerating = true
        progressValue = 0.0
        processedItems = 0
        xmlOutput = ""
        
        // Set up progress callback	
		xmlGenerator.onProgressUpdate = { processed, progress in
		    Task { @MainActor in
		        self.processedItems = processed
		        self.progressValue = progress
		    }
		}
        
        // Run XML generation asynchronously
        Task {
            do {
                // Count total items first
                await MainActor.run {
                    totalItems = xmlGenerator.countItems(at: directory)
                }
                
                // Generate XML with progress tracking
                let xml = try await xmlGenerator.buildXMLAsync(for: directory)
                
                // Update UI on main thread
                await MainActor.run {
                    processedItems = totalItems
                    progressValue = 1.0
                    xmlOutput = xml
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    showErrorMessage("Error generating XML: \(error.localizedDescription)")
                    isGenerating = false
                }
            }
        }
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



#Preview {
    ContentView()
}
