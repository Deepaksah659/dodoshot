import Foundation
import AppKit

/// Service for generating AI descriptions of screenshots
class LLMService {
    static let shared = LLMService()

    private init() {}

    /// Generate a description of an image using the configured LLM provider
    /// - Parameters:
    ///   - image: The screenshot image to describe
    ///   - completion: Callback with description or error
    func describeImage(_ image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        let settings = SettingsManager.shared.settings

        guard !settings.llmApiKey.isEmpty else {
            completion(.failure(LLMError.noAPIKey))
            return
        }

        guard let base64Image = imageToBase64(image) else {
            completion(.failure(LLMError.invalidImage))
            return
        }

        switch settings.llmProvider {
        case .anthropic:
            describeWithAnthropic(base64Image: base64Image, apiKey: settings.llmApiKey, completion: completion)
        case .openai:
            describeWithOpenAI(base64Image: base64Image, apiKey: settings.llmApiKey, completion: completion)
        }
    }

    /// Generate a description (async version)
    @MainActor
    func describeImage(_ image: NSImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            describeImage(image) { result in
                switch result {
                case .success(let description):
                    continuation.resume(returning: description)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Anthropic API

    private func describeWithAnthropic(base64Image: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(LLMError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Please describe this screenshot concisely. Focus on the main content and purpose of what's shown. Keep the description under 100 words."
                        ]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(LLMError.noResponse))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(text))
                    }
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorInfo = json["error"] as? [String: Any],
                          let message = errorInfo["message"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(LLMError.apiError(message)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(LLMError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - OpenAI API

    private func describeWithOpenAI(base64Image: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(LLMError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 500,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Please describe this screenshot concisely. Focus on the main content and purpose of what's shown. Keep the description under 100 words."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(LLMError.noResponse))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(content))
                    }
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorInfo = json["error"] as? [String: Any],
                          let message = errorInfo["message"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(LLMError.apiError(message)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(LLMError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Helpers

    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }
}

// MARK: - LLM Errors
enum LLMError: LocalizedError {
    case noAPIKey
    case invalidImage
    case invalidURL
    case noResponse
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your API key in Settings."
        case .invalidImage:
            return "Could not process the image"
        case .invalidURL:
            return "Invalid API URL"
        case .noResponse:
            return "No response from API"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return message
        }
    }
}
