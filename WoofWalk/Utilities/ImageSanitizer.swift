import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// Central image-preparation utility for uploads.
///
/// Guarantees:
///  1. No EXIF metadata is carried through to the output bytes — GPS, camera
///     model, datetime, etc. are all stripped by re-encoding via `CGImageDestination`
///     with an empty properties dictionary.
///  2. Image orientation is normalised. EXIF orientation is honoured by
///     `UIImage.fixOrientation()` before encoding so the output has no
///     orientation flag and pixels are already correctly oriented.
///  3. Output dimensions are capped — prevents megabyte-scale uploads from
///     long-lens phone cameras.
///  4. Output is JPEG (the only format the Storage rules accept for
///     user-uploaded images).
enum ImageSanitizer {

    /// Kind of image being sanitized — drives the dimension + quality target.
    enum Target {
        case dogPrimary          // 1024px max, quality 0.85
        case dogGallery          // 1024px max, quality 0.85
        case userAvatar          // 512px max, quality 0.85
        case chatMessage         // 1280px max, quality 0.75
        case feedPost            // 1600px max, quality 0.85
        case story               // 1280px max, quality 0.8
        case poi                 // 1600px max, quality 0.8

        var maxDimension: CGFloat {
            switch self {
            case .userAvatar: return 512
            case .dogPrimary, .dogGallery: return 1024
            case .chatMessage, .story: return 1280
            case .feedPost, .poi: return 1600
            }
        }

        var compressionQuality: CGFloat {
            switch self {
            case .chatMessage: return 0.75
            case .story, .poi: return 0.8
            default: return 0.85
            }
        }
    }

    /// Decode → fix orientation → resize if over target → re-encode as JPEG
    /// with no metadata. Returns JPEG bytes ready for Firebase Storage upload.
    ///
    /// Throws if the input data cannot be decoded as an image.
    static func prepareForUpload(imageData: Data, target: Target) throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw ImageSanitizerError.decodingFailed
        }
        return try prepareForUpload(image: image, target: target)
    }

    static func prepareForUpload(image: UIImage, target: Target) throws -> Data {
        // Step 1 — normalise orientation. This renders the bitmap with the
        // EXIF orientation already applied so we can drop orientation metadata.
        let oriented = image.fixOrientation()

        // Step 2 — resize to target max dimension if needed.
        let resized = oriented.resizedIfLarger(than: target.maxDimension)

        // Step 3 — encode with empty metadata dictionary. CGImageDestination
        // is the only way on iOS to control exactly which metadata tags end
        // up in the output file; UIImage.jpegData sometimes re-injects Exif.
        guard let cgImage = resized.cgImage else {
            throw ImageSanitizerError.encodingFailed
        }
        let destData = NSMutableData()
        let jpegType = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(
            destData,
            jpegType,
            1,
            nil
        ) else {
            throw ImageSanitizerError.encodingFailed
        }

        // Only carry content-level properties through — no EXIF, no GPS,
        // no TIFF, no IPTC.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: target.compressionQuality,
            // Explicitly set EXIF/GPS/TIFF to empty to override any defaults.
            kCGImagePropertyExifDictionary: [:] as CFDictionary,
            kCGImagePropertyGPSDictionary: [:] as CFDictionary,
            kCGImagePropertyTIFFDictionary: [:] as CFDictionary,
            kCGImagePropertyIPTCDictionary: [:] as CFDictionary
        ]

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageSanitizerError.encodingFailed
        }

        return destData as Data
    }
}

enum ImageSanitizerError: Error, LocalizedError {
    case decodingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .decodingFailed: return "Could not decode the selected image"
        case .encodingFailed: return "Could not encode the image for upload"
        }
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    /// Returns a bitmap whose pixel data already reflects the EXIF orientation.
    /// The returned UIImage has `.up` orientation with no flag to preserve.
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    /// Resizes down to fit within `maxDimension` × `maxDimension`. Preserves
    /// aspect ratio. Returns self if already within target.
    func resizedIfLarger(than maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        if longest <= maxDimension { return self }

        let scale = maxDimension / longest
        let newSize = CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
