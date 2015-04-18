//
//  Redaction.swift
//  Redacted
//
//  Created by Sam Soffes on 3/23/15.
//  Copyright (c) 2015 Nothing Magical Inc. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(iOS)
	import CoreImage
#else
	import QuartzCore
#endif

public typealias Preprocessor = (image: CIImage, type: RedactionType) -> CIImage

public enum RedactionType: Int, Printable {
	case Pixelate, Blur, BlackBar

	public var description: String {
		switch self {
		case .Pixelate:
			return string("PIXELATE")
		case .Blur:
			return string("BLUR")
		case .BlackBar:
			return string("BLACK_BAR")
		}
	}

	public static var allTypes: [RedactionType] {
		return [.Pixelate, .Blur, .BlackBar]
	}
}

public struct Redaction: Hashable, Equatable {

	public let UUID: String
	public let type: RedactionType
	public var rect: CGRect

	public init(UUID: String = NSUUID().UUIDString, type: RedactionType, rect: CGRect) {
		self.UUID = UUID
		self.type = type
		self.rect = rect
	}

	public var hashValue: Int {
		return UUID.hashValue
	}

	public func rectForBounds(bounds: CGRect) -> CGRect {
		return CGRect(
			x: bounds.origin.x + (rect.origin.x * bounds.size.width),
			y: bounds.origin.y + (rect.origin.y * bounds.size.height),
			width: rect.size.width * bounds.size.width,
			height: rect.size.height * bounds.size.height
		)
	}

	public func filter(image: CIImage, preprocessor: Preprocessor = Redaction.preprocess) -> CIFilter {
		let extent = image.extent()
		let scaledRect = rectForBounds(extent).flippedInRect(extent)
		let processed = preprocessor(image: image, type: type)

		return CIFilter(name: "CISourceOverCompositing", withInputParameters: [
			"inputImage": processed.imageByCroppingToRect(scaledRect)
		])
	}

	public static func preprocess(image: CIImage, type: RedactionType) -> CIImage {
		let extent = image.extent()
		let edge = max(extent.size.width, extent.size.height)

		switch type {
		case .Pixelate:
			return CIFilter(name: "CIPixellate", withInputParameters: [
				"inputScale": edge * 0.01,
				"inputCenter": CIVector(CGPoint: extent.center),
				"inputImage": image
			])!.outputImage

		case .Blur:
			#if os(iOS)
				let transform = NSValue(CGAffineTransform: CGAffineTransformIdentity)
				#else
				let transform = NSAffineTransform()
			#endif

			let clamp = CIFilter(name: "CIAffineClamp", withInputParameters: [
				"inputTransform": transform,
				"inputImage": image
			])

			return CIFilter(name: "CIGaussianBlur", withInputParameters: [
				"inputRadius": edge * 0.01,
				"inputImage": clamp.outputImage
			])!.outputImage

		case .BlackBar:
			return CIFilter(name: "CIConstantColorGenerator", withInputParameters: [
				"inputColor": CIColor(red: 0, green: 0, blue: 0, alpha: 1)
			]).outputImage
		}
	}
}


extension Redaction {
	var dictionaryRepresentation: [String: AnyObject] {
		return [
			"UUID": UUID,
			"type": type.rawValue,
			"rect": rect.stringRepresentation
		]
	}

	init?(dictionary: [String: AnyObject]) {
		if let UUID = dictionary["UUID"] as? String, typeString = dictionary["type"] as? Int, type = RedactionType(rawValue: typeString), rectString = dictionary["rect"] as? String {
			self.UUID = UUID
			self.type = type
			self.rect = CGRect(string: rectString)
			return
		}
		return nil
	}
}


public func ==(lhs: Redaction, rhs: Redaction) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
