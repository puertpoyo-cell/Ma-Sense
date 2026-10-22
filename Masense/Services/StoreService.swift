import Foundation
import StoreKit

/// StoreKit 2 비소모성 1종 (PRD 10. 수익 모델). 리포트 PDF 내보내기·테마를 연다.
/// 기록·알림·컨디션 체크는 전부 무료이므로 구매 상태가 건강 안전과 무관하다 (COMPLIANCE.md 4.4).
protocol StorePurchasing: AnyObject {
    /// 표시용 상품 정보. 로드 실패 시 nil
    func loadProduct() async -> StoreProductInfo?
    /// 현재 소유 여부 (StoreKit이 진실 원천)
    func refreshEntitlement() async -> Bool
    func purchase() async throws -> Bool
    func restore() async throws -> Bool
}

struct StoreProductInfo: Equatable {
    let displayName: String
    let displayPrice: String
}

enum StoreError: Error {
    case productUnavailable
    case unverified
}

final class StoreService: StorePurchasing {
    /// App Store Connect의 상품 ID (2026-10-22 확정). 결제 상품 구성 변경은 사람 확인 후 (CLAUDE.md)
    static let productID = "com.masense.pro"

    private var product: Product?

    func loadProduct() async -> StoreProductInfo? {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        guard let product else { return nil }
        return StoreProductInfo(displayName: product.displayName, displayPrice: product.displayPrice)
    }

    func refreshEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func purchase() async throws -> Bool {
        if product == nil {
            product = try await Product.products(for: [Self.productID]).first
        }
        guard let product else { throw StoreError.productUnavailable }

        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw StoreError.unverified }
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        return await refreshEntitlement()
    }
}

/// 테스트·미리보기용
final class FakeStoreService: StorePurchasing {
    var purchased = false
    var product: StoreProductInfo? = StoreProductInfo(displayName: "Masense Pro", displayPrice: "₩9,900")

    func loadProduct() async -> StoreProductInfo? { product }
    func refreshEntitlement() async -> Bool { purchased }
    func purchase() async throws -> Bool {
        purchased = true
        return true
    }
    func restore() async throws -> Bool { purchased }
}
