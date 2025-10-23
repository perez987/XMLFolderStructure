import Foundation

/// A class responsible for generating XML from directory structure
class XMLGenerator {
    
    // Progress tracking callback
    var onProgressUpdate: ((Int, Double) -> Void)?
    
    private var totalItems: Int = 0
    private var processedItems: Int = 0
    
    // MARK: - Public Methods
    
    /// Counts the number of items (files and folders) in a directory recursively
    /// - Parameter url: The directory URL to count items in
    /// - Returns: The total count of items
    func countItems(at url: URL) -> Int {
        var count = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case _ as URL in enumerator {
            count += 1
        }
        
        return count
    }
    
    /// Calculates the total size of a directory recursively
    /// - Parameter url: The directory URL to calculate size for
    /// - Returns: The total size in bytes
    func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  let isDirectory = resourceValues.isDirectory else {
                continue
            }
            
            // Only count file sizes, not directories
            if !isDirectory, let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    /// Generates XML structure for a directory synchronously
    /// - Parameter url: The directory URL to generate XML for
    /// - Returns: The XML string representation
    /// - Throws: An error if directory reading fails
    func buildXML(for url: URL) throws -> String {
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
    
    /// Generates XML structure for a directory asynchronously with progress tracking
    /// - Parameter url: The directory URL to generate XML for
    /// - Returns: The XML string representation
    /// - Throws: An error if directory reading fails
    func buildXMLAsync(for url: URL) async throws -> String {
        // Reset progress tracking
        processedItems = 0
        totalItems = countItems(at: url)
        
        var xml = ""
        let directoryName = xmlEscape(url.lastPathComponent)
        
        // Root directory opening tag
        xml += "<root name=\"\(directoryName)\" text=\"Root directory\">\n"
        
        // Process directory contents recursively
        xml += try await processDirectoryAsync(at: url, indentLevel: 1)
        
        // Closing tag
        xml += "</root>\n"
        
        return xml
    }
    
    // MARK: - Private Methods
    
    /// Escapes special XML characters in a string
    /// - Parameter string: The string to escape
    /// - Returns: The escaped string
    private func xmlEscape(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
    
    /// Formats a file size in bytes with dot separators
    /// - Parameter size: The file size in bytes
    /// - Returns: A formatted string representation of the file size
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
    
    /// Processes a directory recursively to generate XML
    /// - Parameters:
    ///   - url: The directory URL to process
    ///   - indentLevel: The current indentation level
    /// - Returns: The XML string for this directory and its contents
    /// - Throws: An error if directory reading fails
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
    
    /// Processes a directory recursively to generate XML asynchronously
    /// - Parameters:
    ///   - url: The directory URL to process
    ///   - indentLevel: The current indentation level
    /// - Returns: The XML string for this directory and its contents
    /// - Throws: An error if directory reading fails
    private func processDirectoryAsync(at url: URL, indentLevel: Int) async throws -> String {
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
                    xml += try await processDirectoryAsync(at: item, indentLevel: indentLevel + 1)
                    
                    // Close folder tag
                    xml += "\(indent)</folder>\n"
                } else {
                    // File tag with size and date attributes
                    let fileSize = (resourceValues.fileSize) ?? 0
                    let formattedSize = formatFileSize(fileSize)
                    
                    let modificationDate = resourceValues.contentModificationDate ?? Date()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "d/M/yyyy"
                    let formattedDate = dateFormatter.string(from: modificationDate)
                    
                    xml += "\(indent)<file name=\"\(name)\" size=\"\(formattedSize)\" modified=\"\(formattedDate)\" />\n"
                }
                
                // Update progress
                processedItems += 1
                let progress = totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0.0
                onProgressUpdate?(processedItems, progress)
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
}
