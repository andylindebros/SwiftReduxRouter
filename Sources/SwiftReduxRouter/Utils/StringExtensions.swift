import Foundation

extension String {

    func replaceFirstExpression(of pattern:String,
                                   with replacement:String) -> String {
        if let range = self.range(of: pattern) {
            return self.replacingCharacters(in: range, with: replacement)
        } else {
            return self
        }
    }
}
