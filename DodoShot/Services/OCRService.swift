import Foundation
import Vision
import AppKit

/// Service for extracting text from images using Apple's Vision framework
class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Extract text from an NSImage
    /// - Parameters:
    ///   - image: The image to extract text from
    ///   - completion: Callback with extracted text or error
    func extractText(from image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion(.failure(OCRError.noTextFound))
                }
                return
            }

            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            DispatchQueue.main.async {
                if text.isEmpty {
                    completion(.failure(OCRError.noTextFound))
                } else {
                    completion(.success(text))
                }
            }
        }

        // Configure for best accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Extract text from an NSImage (async version)
    @MainActor
    func extractText(from image: NSImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            extractText(from: image) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Copy extracted text to clipboard
    func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - OCR Errors
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .noTextFound:
            return "No text found in the image"
        }
    }
}
