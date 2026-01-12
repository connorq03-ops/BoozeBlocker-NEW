import Foundation

extension String {
    /// Returns the string with only alphanumeric characters
    var alphanumericOnly: String {
        return self.filter { $0.isLetter || $0.isNumber }
    }
    
    /// Returns true if the string contains only digits
    var isNumeric: Bool {
        return !isEmpty && allSatisfy { $0.isNumber }
    }
    
    /// Truncates the string to a maximum length with ellipsis
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
    
    /// Formats a phone number for display
    var formattedPhoneNumber: String {
        let digits = self.filter { $0.isNumber }
        
        guard digits.count == 10 else { return self }
        
        let areaCode = digits.prefix(3)
        let middle = digits.dropFirst(3).prefix(3)
        let last = digits.suffix(4)
        
        return "(\(areaCode)) \(middle)-\(last)"
    }
}
