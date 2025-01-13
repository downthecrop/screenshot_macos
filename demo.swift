import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

// This program captures a screenshot using Apple's ScreenCaptureKit framework.
// It detects multiple monitors and allows capturing from a specific display or the main display.

// To run this program:
// 1. Make sure you have Xcode and Swift installed on your Mac.
// 2. Save this code in a file named 'demo.swift'.
// 3. Open Terminal, navigate to the directory containing the file.
// 4. Run: swift demo.swift

// Function to list active windows
func listActiveWindows() async {
    do {
        let content = try await SCShareableContent.current

        guard !content.windows.isEmpty else {
            print("No windows found")
            return
        }

        print("Available windows:")
        for (index, window) in content.windows.enumerated() {
            let appName = window.owningApplication?.bundleIdentifier ?? "Unknown Application"
            let windowName = window.title ?? "Unnamed Window"
            print("\(index + 1). App: \(appName), Window: \(windowName)")
        }
    } catch {
        print("Error fetching active windows: \(error.localizedDescription)")
    }
}

// Function to capture a screenshot
func captureScreenshot(display: SCDisplay?, excludeApplication: String, completion: @escaping (NSImage?) -> Void) {
    Task {
        do {
            let content = try await SCShareableContent.current
            
            // Exclude windows owned by the specified application
            let excludedWindows = content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == excludeApplication
            }
            
            let filter: SCContentFilter
            if let display = display {
                filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: excludedWindows)
            } else {
                filter = SCContentFilter()
            }
            
            let configuration = SCStreamConfiguration()
            configuration.width = 1920 // Adjust as needed
            configuration.height = 1080 // Adjust as needed
            configuration.showsCursor = true
            configuration.scalesToFit = false

            if #available(macOS 14.0, *) {
                SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                    if let error = error {
                        print("Error capturing screenshot: \(error.localizedDescription)")
                        completion(nil)
                    } else if let image = image {
                        completion(NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                    } else {
                        print("No image captured")
                        completion(nil)
                    }
                }
            } else {
                print("macOS 14.0 or later is required for capturing screenshots using ScreenCaptureKit.")
                completion(nil)
            }
        } catch {
            print("Error setting up content filter: \(error.localizedDescription)")
            completion(nil)
        }
    }
}

// Main execution
func main() {
    let semaphore = DispatchSemaphore(value: 0)

    Task {
        // Step 1: List all active windows
        await listActiveWindows()

        // Step 2: Get displays and capture screenshot
        do {
            let content = try await SCShareableContent.current

            guard !content.displays.isEmpty else {
                print("No displays found")
                semaphore.signal()
                return
            }

            print("\nAvailable displays:")
            for (index, display) in content.displays.enumerated() {
                print("\(index + 1). \(display.displayID) - \(display.width)x\(display.height)")
            }

            print("\nEnter the number of the display to capture (or press Enter for main display):")
            let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)

            let selectedDisplay: SCDisplay?
            if let index = Int(input ?? ""), (1...content.displays.count).contains(index) {
                selectedDisplay = content.displays[index - 1]
            } else {
                selectedDisplay = content.displays.first
            }

            // Exclude the application with bundle ID `com.apple.dt.Xcode`
            captureScreenshot(display: selectedDisplay, excludeApplication: "com.apple.dt.Xcode") { image in
                if let image = image {
                    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    let fileURL = currentDirectoryURL.appendingPathComponent("screenshot.png")

                    if let tiffData = image.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        do {
                            try pngData.write(to: fileURL)
                            print("Screenshot saved to: \(fileURL.path)")
                        } catch {
                            print("Error saving screenshot: \(error.localizedDescription)")
                        }
                    } else {
                        print("Error converting image to PNG data")
                    }
                } else {
                    print("Failed to capture screenshot")
                }
                semaphore.signal()
            }
        } catch {
            print("Error getting shareable content: \(error.localizedDescription)")
            semaphore.signal()
        }
    }

    semaphore.wait()
}

main()
