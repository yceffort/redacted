//
//  WindowController.swift
//  Redacted
//
//  Created by Sam Soffes on 3/23/15.
//  Copyright (c) 2015 Nothing Magical Inc. All rights reserved.
//

import Cocoa
import RedactedKit

class WindowController: NSWindowController {

	// MARK: - Properties

	@IBOutlet var toolbar: NSToolbar!
	@IBOutlet var shareItem: NSToolbarItem!
	@IBOutlet var modeControl: NSSegmentedControl!

	var editorViewController: EditorViewController!
	var modeIndex: Int = 0 {
		didSet {
			invalidateRestorableState()

			modeControl.selectedSegment = modeIndex

			if let mode = RedactionType(rawValue: modeIndex) {
				editorViewController.redactedLayer.mode = mode
			}
		}
	}

	private let _undoManager = NSUndoManager()


	// MARK: - Initializers

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}


	// MARK: - NSResponder

	override func encodeRestorableStateWithCoder(coder: NSCoder) {
		super.encodeRestorableStateWithCoder(coder)

		coder.encodeInteger(modeControl.selectedSegment, forKey: "modeIndex")
	}


	override func restoreStateWithCoder(coder: NSCoder) {
		super.restoreStateWithCoder(coder)

		modeIndex = coder.decodeIntegerForKey("modeIndex")
	}


	// MARK: - NSWindowController

	override func windowDidLoad() {
		super.windowDidLoad()

		window?.delegate = self

		editorViewController = contentViewController as? EditorViewController
		editorViewController.redactedLayer.undoManager = window?.undoManager

		if let view = editorViewController.view as? ImageDragDestinationView {
			view.delegate = self
		}

		// Setup share button
		if let button = shareItem.view as? NSButton {
			button.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))
		}

		// Validate toolbar
		validateToolbar()

		// Notifications
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "imageDidChange:", name: EditorViewController.imageDidChangeNotification, object: nil)
	}


	// MARK: - Actions

	func openDocument(sender: AnyObject?) {
		let openPanel = NSOpenPanel()
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = false
		openPanel.canCreateDirectories = false
		openPanel.canChooseFiles = true
		openPanel.beginSheetModalForWindow(window!) { result in
			if let URL = openPanel.URL where result == NSFileHandlingPanelOKButton {
				self.openURL(URL)
			}
		}
	}

	func save(sender: AnyObject?) {
		if let window = window, image = editorViewController.renderedImage {
			let savePanel = NSSavePanel()
			savePanel.allowedFileTypes = ["png"]
			savePanel.beginSheetModalForWindow(window) {
				if $0 == NSFileHandlingPanelOKButton {
					if let path = savePanel.URL?.path, cgImage = image.CGImageForProposedRect(nil, context: nil, hints: nil)?.takeUnretainedValue() {
						let rep = NSBitmapImageRep(CGImage: cgImage)
						let data = rep.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [NSObject: AnyObject]())
						data?.writeToFile(path, atomically: true)
					}
				}
			}
		}
	}

	func copy(sender: AnyObject?) {
		if let image = editorViewController.renderedImage {
			let pasteboard = NSPasteboard.generalPasteboard()
			pasteboard.clearContents()
			pasteboard.writeObjects([image])
		}
	}

	func paste(sender: AnyObject?) {
		if let data = NSPasteboard.generalPasteboard().dataForType(String(kUTTypeTIFF)) {
			editorViewController.image = NSImage(data: data)
		}
	}

	func delete(sender: AnyObject?) {
		editorViewController.redactedLayer.delete()
	}

	override func selectAll(sender: AnyObject?) {
		editorViewController.redactedLayer.selectAll()
	}

	@IBAction func modeDidChange(sender: AnyObject?) {
		modeIndex = modeControl.selectedSegment
	}

	@IBAction func clearImage(sender: AnyObject?) {
		editorViewController.image = nil
	}

	@IBAction func shareImage(sender: AnyObject?) {
		editorViewController.shareImage(fromView: shareItem.view!)
	}


	// MARK: - Public

	func openURL(URL: NSURL?) -> Bool {
		if let URL = URL, image = NSImage(contentsOfURL: URL) {
			NSDocumentController.sharedDocumentController().noteNewRecentDocumentURL(URL)
			self.editorViewController.image = image
			return true
		}
		return false
	}


	// MARK: - Private

	func imageDidChange(notification: NSNotification?) {
		NSRunningApplication.currentApplication().activateWithOptions(.ActivateIgnoringOtherApps)
		validateToolbar()
	}
}


extension WindowController: NSWindowDelegate {
	func windowWillClose(notification: NSNotification) {
		NSApplication.sharedApplication().terminate(window)
	}

	func windowWillReturnUndoManager(window: NSWindow) -> NSUndoManager? {
		return _undoManager
	}
}


extension WindowController {
	private func validateToolbar() {
		if let items = toolbar.visibleItems as? [NSToolbarItem] {
			for item in items {
				item.enabled = validateToolbarItem(item)
			}
		}
	}

	override func validateToolbarItem(theItem: NSToolbarItem) -> Bool {
		if contains(["mode", "clear", "share"], theItem.itemIdentifier) {
			return editorViewController.image != nil
		}
		return true
	}
}


extension WindowController: ImageDragDestinationViewDelegate {
	func imageDragDestinationView(imageDragDestinationView: ImageDragDestinationView, didAcceptImage image: NSImage) {
		editorViewController.image = image
	}

	func imageDragDestinationView(imageDragDestinationView: ImageDragDestinationView, didAcceptURL URL: NSURL) {
		openURL(URL)
	}
}