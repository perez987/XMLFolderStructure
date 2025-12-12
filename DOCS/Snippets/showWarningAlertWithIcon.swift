    // MARK: - Alert Helper
    
    private func showWarningAlertWithIcon() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Warning:", comment: "")
        alert.informativeText = String(format: NSLocalizedString("WarningMessage:", comment: ""), directoryItemCount)
            // alertStyle = .warning has issues rendering Continue button on macOS 15+
//		alert.alertStyle = .informational

			// Remove SF Symbol icon if the Continue button does not render properly
			// The .warning alertStyle already provides a suitable warning icon
//		if let warningImage = NSImage(systemSymbolName:  "exclamationmark.triangle", accessibilityDescription: "Warning") {
//			alert.icon = warningImage
//		}
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
				// Additional fix for standalone app: Center alert relative to main window
				// This ensures proper positioning while maintaining button visibility
			if let mainWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
				alert.window.center()
				alert.window.setFrameOrigin(NSPoint(
					x: mainWindow.frame.midX - alert.window.frame.width / 2,
					y: mainWindow.frame.midY - alert.window.frame.height / 2
				))
			}
				// Process pending events to ensure rendering is complete
				// Small delay allows the window system to fully initialize
			alert.window.makeKeyAndOrderFront(nil)
//			alert.window.center()
			RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
		}

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
				// Continue button clicked
            performGenerateXML()
        }
        // If cancel or closed, do nothing
    }
