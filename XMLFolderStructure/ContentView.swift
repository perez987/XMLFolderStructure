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
    @State private var useSyntaxHighlighting: Bool = true

	@State private var showAlert = false

    private let xmlGenerator = XMLGenerator()
    
    var body: some View {
        VStack(spacing: 20) {
            // Top section: Directory selection
            VStack(spacing: 10) {
                HStack {
                    Text(NSLocalizedString("Selected directory:", comment: ""))
                    
                    TextField(NSLocalizedString("No directory selected:", comment: ""), text: .constant(selectedDirectory?.path ?? NSLocalizedString("No directory selected:", comment: "")))
                        .disabled(true)
//						.border(Color.secondary, width: 1)
						.overlay(
							RoundedRectangle(cornerRadius: 18)
								.stroke(Color.secondary, lineWidth: 0.4)
						)

                    Button(NSLocalizedString("Browse:", comment: "")) {
                        selectDirectory()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    Button(NSLocalizedString("Generate XML:", comment: "")) {
                        generateXML()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedDirectory == nil || isGenerating)

					Button {
						showAlert = true
					} label: {
						Image(systemName: "info.circle")
							.font(.system(size: 18))
							.foregroundColor(.secondary)
					}
					.buttonStyle(.borderless)
					.alert("Performance Warning", isPresented: $showAlert) {
						Button("Understood") {
						}
					} message: {
						Text("GenerateXML Alert")
					}

                }
                
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
						.border(Color.secondary, width: 0.4)

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
        .frame(minWidth: 700, minHeight: 790)

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
        
        // Count items in the directory
        directoryItemCount = xmlGenerator.countItems(at: directory)

        // Determine if we should use syntax highlighting
        useSyntaxHighlighting = directoryItemCount <= 10000

				// Generate XML output
            performGenerateXML()
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
		// Wraps NSTextView for displaying attributed text in SwiftUI
		// Configures text view as non-editable but selectable
		// Updates display when attributedString binding changes
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
