import Foundation

/// What someone typed into a page field, turned into a number.
///
/// The field is labelled `p.`, and people type the label back into it. Anything
/// that isn't a single page — blank, zero, a range, prose — is no page, because
/// `p.0` on a source line reads as a bug and is one.
///
/// Shared by the capture sheet's page field and the book form's two page
/// counts, so the three can't disagree about what `p. 214` means.
nonisolated enum TypedPage {

    static func parse(_ typed: String) -> Int? {
        let digits = typed.filter(\.isNumber)
        guard !digits.isEmpty, !typed.contains("-"), let number = Int(digits), number > 0
        else { return nil }
        return number
    }
}
