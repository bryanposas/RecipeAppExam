// Extensions/String+DietaryAttribute.swift

import Foundation

extension String {
    /// Returns the matching `DietaryAttribute` case, or `nil` for unknown values.
    var asDietaryAttribute: DietaryAttribute? {
        DietaryAttribute(rawValue: self.lowercased())
    }
}
