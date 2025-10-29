import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedDirectory: URL?
    @State private var xmlOutput: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var highlightedXML: NSAttributedString = NSAttributedString()
    @State private var isGenerating: Bool = false
    @State private var progressValue: Double = 0.0
    @State private var totalItems: Int = 0
    @State private var processedItems: Int = 0
    @State private var directoryItemCount: Int = 0
    @State private var directorySize: Int64 = 0
    @State private var useSyntaxHighlighting: Bool = true
    
    private let xmlGenerator = XMLGenerator()
    
    var body: some View {
        VStack(spacing: 20) {
            // Top section: Directory selection
            VStack(spacing: 10) {
                HStack {
                    Text(NSLocalizedString("Selected directory:", comment: ""))
                    
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
                        Text("\(NSLocalizedString("Processing:", comment: "")) \(processedItems) / \(totalItems) \(NSLocalizedString("items", comment: ""))")
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

                    SyntaxHighlightedTextView(attributedString: $highlightedXML)
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
    
    // MARK: - Alert Helper
    
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
        
        // Count items and calculate size in the directory
        directoryItemCount = xmlGenerator.countItems(at: directory)
        directorySize = xmlGenerator.calculateDirectorySize(at: directory)
        
        // Determine if we should use syntax highlighting
        useSyntaxHighlighting = directoryItemCount <= 10000
        
        // Only show warning if directory has more than 10000 items OR more than 1GB
//        let oneGigabyte: Int64 = 1_073_741_824 // 1GB in bytes
//        if directoryItemCount > 10000 || directorySize > oneGigabyte {
        // Only show warning if directory has more than 12000 items
        if directoryItemCount > 10000 {
            showWarningAlertWithIcon()
        } else {
            // Directly generate XML if conditions are not met
            performGenerateXML()
        }
    }
    
    private func performGenerateXML() {
        guard let directory = selectedDirectory else {
            showErrorMessage("No directory selected")
            return
        }
        
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
        
        // Run XML generation asynchronously
        Task {
            do {
                // Count total items first
                await MainActor.run {
                    totalItems = directoryItemCount
                }
                
                // Generate XML with progress tracking
                let xml = try await xmlGenerator.buildXMLAsync(for: directory)
                
                // Update UI on main thread
                await MainActor.run {
                    xmlOutput = xml
                    // Apply syntax highlighting only if directory has <= 10000 items
                    if useSyntaxHighlighting {
                        highlightedXML = XMLSyntaxHighlighter.highlight(xml)
                    } else {
                        // Use plain text without syntax highlighting
                        let plainText = NSAttributedString(string: xml, attributes: [
                            .font: NSFont.systemFont(ofSize: 12),
                            .foregroundColor: NSColor.textColor
                        ])
                        highlightedXML = plainText
                    }
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
