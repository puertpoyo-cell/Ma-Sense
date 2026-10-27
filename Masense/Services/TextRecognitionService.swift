import UIKit
import Vision

/// 사진 속 글자 읽기 (D20). Apple Vision으로 기기 안에서만 처리하고 사진·글자를 밖으로 보내지 않는다.
/// 줄 묶기와 항목 찾기는 `LabRules` (테스트 대상)
enum TextRecognitionService {
    static func boxes(in image: UIImage) async -> [TextBox] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let boxes = observations.compactMap { observation -> TextBox? in
                    guard let text = observation.topCandidates(1).first?.string else { return nil }
                    let box = observation.boundingBox
                    // Vision은 아래쪽이 0이다. 위쪽 0으로 바꾼다
                    return TextBox(text: text, minX: box.minX, midY: 1 - box.midY, height: box.height)
                }
                continuation.resume(returning: boxes)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// 검사지 사진 → 항목 후보
    static func labCandidates(in image: UIImage) async -> [LabCandidate] {
        LabRules.candidates(lines: LabRules.lines(from: await boxes(in: image)))
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
