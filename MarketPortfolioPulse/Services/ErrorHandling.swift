import Foundation

extension Error {
    /// True when the failure is just a cancelled task — SwiftUI tears down
    /// `.task` work when a view goes away (tab switches, superseded
    /// refreshes), and URLSession reports that as `URLError.cancelled`.
    /// Cancellation is normal control flow, never something to show the
    /// user as an error.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// The message to surface, or nil when the failure should stay silent.
    var userFacingMessage: String? {
        isCancellation ? nil : localizedDescription
    }
}
