import Foundation
@preconcurrency import Vision
import CoreGraphics
import ImageIO

public struct OCRLine: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect
}

public final class OCRService {
    public init() {}

    public func recognize(data: Data) async throws -> [OCRLine] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw NSError(domain: "OCRService", code: 1) }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { observation -> OCRLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRLine(text: candidate.string, confidence: candidate.confidence, boundingBox: observation.boundingBox)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
