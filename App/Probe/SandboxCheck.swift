import Foundation
import PSKReporterCore

/// A separate diagnostic bundle exercises real sandbox enforcement and
/// preferences persistence without accessing the user's monitoring settings.
@MainActor
enum SandboxCheck {
    static func run(phase: String, blockedFile: String, callsign: String) -> Never {
        guard let identifier = Bundle.main.bundleIdentifier,
              identifier == "com.tallackn.PSKReporterCounter.SandboxCheck",
              Callsign.isValid(callsign), ["write", "read"].contains(phase) else {
            fail("Run this check through scripts/check-sandbox.sh.")
        }
        guard NSHomeDirectory().contains("/Library/Containers/\(identifier)/Data") else {
            fail("The diagnostic is not using its app sandbox container.")
        }
        do {
            _ = try Data(contentsOf: URL(fileURLWithPath: blockedFile))
            fail("The sandbox allowed an ungranted file outside its container.")
        } catch {
            let error = error as NSError
            let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
            let denied = (error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError)
                || (underlying?.domain == NSPOSIXErrorDomain && [1, 13].contains(underlying?.code ?? 0))
            guard denied else { fail("Unexpected file boundary error: \(error)") }
            print("Sandbox denied the controlled file outside its container.")
        }
        guard let licenceURL = Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
              (try? String(contentsOf: licenceURL, encoding: .utf8).contains("MIT License")) == true else {
            fail("The sandbox could not read a bundled licence resource.")
        }
        let defaults = UserDefaults.standard
        if phase == "write" {
            defaults.set(callsign, forKey: "callsign")
            defaults.set("+", forKey: "band")
            defaults.set("+", forKey: "mode")
            defaults.set(15, forKey: "intervalMinutes")
            defaults.set(false, forKey: "countUniqueStations")
            defaults.set(true, forKey: "hideDockIcon")
            defaults.set(true, forKey: "sandboxCheckWritten")
            guard defaults.synchronize() else { fail("Could not persist sandbox preferences.") }
        } else {
            let monitor = MonitorModel(defaults: defaults)
            guard defaults.bool(forKey: "sandboxCheckWritten"), monitor.callsign == callsign,
                  monitor.interval == .fifteen, !monitor.countUniqueStations,
                  monitor.hideDockIcon, monitor.isRunning else {
                fail("The monitoring model did not restore sandbox preferences after relaunch.")
            }
            for key in ["callsign", "band", "mode", "intervalMinutes", "countUniqueStations", "hideDockIcon", "sandboxCheckWritten"] {
                defaults.removeObject(forKey: key)
            }
            _ = defaults.synchronize()
        }
        print("Sandbox preferences \(phase) passed; bundled resources are readable.")
        fflush(stdout)
        exit(0)
    }

    private static func fail(_ message: String) -> Never {
        print("Sandbox check failed: \(message)")
        fflush(stdout)
        exit(1)
    }
}
