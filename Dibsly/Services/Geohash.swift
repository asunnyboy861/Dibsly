import Foundation

enum Geohash {
    private static let base32: [Character] = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        guard precision > 0 else { return "" }
        var latInterval = (-90.0, 90.0)
        var lonInterval = (-180.0, 180.0)
        var isEven = true
        var bit = 0
        var characterIndex = 0
        var hash = ""

        while hash.count < precision {
            if isEven {
                let mid = (lonInterval.0 + lonInterval.1) / 2
                if longitude > mid {
                    characterIndex = characterIndex * 2 + 1
                    lonInterval.0 = mid
                } else {
                    characterIndex = characterIndex * 2
                    lonInterval.1 = mid
                }
            } else {
                let mid = (latInterval.0 + latInterval.1) / 2
                if latitude > mid {
                    characterIndex = characterIndex * 2 + 1
                    latInterval.0 = mid
                } else {
                    characterIndex = characterIndex * 2
                    latInterval.1 = mid
                }
            }
            isEven.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[characterIndex])
                bit = 0
                characterIndex = 0
            }
        }
        return hash
    }

    static func cellSizeMeters(precision: Int) -> Double {
        switch precision {
        case 3: return 78000
        case 4: return 19500
        case 5: return 4900
        case 6: return 1200
        default: return 4900
        }
    }
}
