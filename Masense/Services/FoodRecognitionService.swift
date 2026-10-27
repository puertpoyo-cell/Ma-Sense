import UIKit
import Vision

/// 사진 속 음식 종류 짐작 (D20). Apple Vision 이미지 분류를 기기 안에서만 쓰고 사진은 저장하지 않는다.
/// 이름 → 식품 매핑은 `FoodPhotoRules` (테스트 대상)
enum FoodRecognitionService {
    static func labels(in image: UIImage) async -> [(identifier: String, confidence: Double)] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                continuation.resume(returning: observations.map { ($0.identifier, Double($0.confidence)) })
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    static func foods(in image: UIImage) async -> [ProteinFood] {
        FoodPhotoRules.foods(from: await labels(in: image))
    }
}
