import Foundation

/// What someone typed into a page field, turned into a number.
///
/// The field is labelled `p.`, and people type the label back into it. Anything
/// that isn't a single page — blank, zero, a range, prose — is no page, because
/// `p.0` on a source line reads as a bug and is one.
///
/// Shared by the capture sheet's page field — through `CaptureDraft` — and the
/// book form's page count, so the two can't disagree about what `p. 214` means.
/// That claim was false from phase 4 to phase 11: `CaptureDraft` carried its own
/// identical copy of the rule the whole time.
nonisolated enum TypedPage {

    static func parse(_ typed: String) -> Int? {
        let digits = typed.filter(\.isNumber)
        guard !digits.isEmpty, !typed.contains("-"), let number = Int(digits), number > 0
        else { return nil }
        return number
    }
}
