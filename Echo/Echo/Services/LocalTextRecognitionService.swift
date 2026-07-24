import Foundation
import Vision

enum LocalTextRecognitionError: LocalizedError {
    case noText

    var errorDescription: String? {
        "No readable text was found in this image."
    }
}

enum LocalTextRecognitionService {
    static func recognizeText(in imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]

            let handler = VNImageRequestHandler(data: imageData)
            try handler.perform([request])

            let lines = (request.results ?? []).compactMap {
                $0.topCandidates(1).first?.string
            }
            guard !lines.isEmpty else { throw LocalTextRecognitionError.noText }
            return lines.joined(separator: "\n")
        }.value
    }
}
