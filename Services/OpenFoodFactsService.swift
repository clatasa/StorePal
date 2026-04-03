import Foundation

struct ProductResult {
    let name: String
    let brand: String?
    let quantity: String?
}

actor OpenFoodFactsService {

    static let shared = OpenFoodFactsService()
    private init() {}

    func lookup(barcode: String) async throws -> ProductResult? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,brands,quantity") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("StorePal iOS App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            return nil
        }

        let name     = (product["product_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let brand    = (product["brands"]        as? String)?.trimmingCharacters(in: .whitespaces)
        let quantity = (product["quantity"]      as? String)?.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else { return nil }

        return ProductResult(
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            quantity: quantity.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
