import Foundation
import LocalAuthentication

/// Face ID / Touch ID, with the iPhone passcode as fallback.
struct BiometricLock {
    /// Tests replace the real prompt.
    var evaluate: (String) async -> Bool = BiometricLock.systemPrompt

    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var biometryName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return String(localized: "Passcode")
        }
    }

    func authenticate(reason: String) async -> Bool {
        await evaluate(reason)
    }

    static func systemPrompt(_ reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
