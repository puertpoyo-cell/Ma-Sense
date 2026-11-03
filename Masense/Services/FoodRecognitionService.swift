import UIKit
import Vision

/// 사진 속 음식 종류 짐작 (D20, D39). Apple Vision 이미지 분류를 기기 안에서만 쓰고 사진은 저장하지 않는다.
/// D39: 사진을 여러 조각(전체·귀퉁이·가운데)으로 나눠 보고, 포장·메뉴판 글자도 읽는다.
/// 이름 → 식품 매핑은 `FoodPhotoRules` (테스트 대상)
enum FoodRecognitionService {
    struct Reading {
        let labels: [(identifier: String, confidence: Double)]
        let lines: [String]
        var foods: [ProteinFood] { FoodPhotoRules.foods(labels: labels, text: lines) }
        var packageGrams: Double? { FoodPhotoRules.labelProteinGrams(in: lines) }
    }

    static func read(_ image: UIImage) async -> Reading {
        async let labels = labels(in: image)
        async let lines = TextRecognitionService.lines(in: image)
        return await Reading(labels: labels, lines: lines)
    }

    /// 조각마다 분류해 이름별 가장 높은 확신도로 합친다
    static func labels(in image: UIImage) async -> [(identifier: String, confidence: Double)] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        var runs: [[(identifier: String, confidence: Double)]] = []
        for rect in FoodPhotoRules.cropRects {
            runs.append(await classify(cgImage, region: rect, orientation: orientation))
        }
        return FoodPhotoRules.merged(runs)
    }

    private static func classify(_ cgImage: CGImage, region: CGRect, orientation: CGImagePropertyOrientation) async -> [(identifier: String, confidence: Double)] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                continuation.resume(returning: observations.map { ($0.identifier, Double($0.confidence)) })
            }
            // Vision의 관심 영역은 아래쪽이 0
            request.regionOfInterest = CGRect(x: region.minX, y: 1 - region.maxY, width: region.width, height: region.height)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    static func foods(in image: UIImage) async -> [ProteinFood] {
        await read(image).foods
    }
}
