# Licence inventory

Audited against Package.resolved on 27 September 2026. The original app source
and documentation use the MIT licence in the repository root. These notices
do not change the licences of third-party components.

| Component | Version | Attribution and licence |
| --- | --- | --- |
| CocoaMQTT | 2.4.1 | emqx.io and contributors. EDL 1.0 selected from the top-level EPL 1.0 / EDL 1.0 dual licence. |
| MqttCocoaAsyncSocket | 1.0.8 | Deusty LLC, Robbie Hanson, Dustin Voss and the CocoaAsyncSocket community. The BSD option in LICENSE.txt is selected. |
| Starscream | 4.0.8 | Dalton Cherry. Apache 2.0. Optional package resolved by CocoaMQTT, not linked by the app's CocoaMQTT core target. Its notice is retained for completeness. |
| Swift | System toolchain/runtime | Apache 2.0 with Runtime Library Exception. Included as an acknowledgement. |
| Apple frameworks | Supplied by macOS | Apple and the respective rights holders' terms. Framework binaries are not copied into the app. |

## Provenance

- CocoaMQTT revision: 4c5a9a68eac0a4eab74ba504981e5a839d7e7593.
  Its podspec says MIT, but its actual top-level LICENSE explicitly offers
  EPL 1.0 and EDL 1.0. The licence files govern this inventory, not that
  inconsistent package metadata. The upstream edl-v10 file is zero bytes.
  CocoaMQTT-EDL-1.0.txt is the complete canonical text from
  https://www.eclipse.org/org/documents/edl-v10/EDL-1.0.txt.
  Copyright notices are preserved in CocoaMQTT-NOTICES.txt.
- MqttCocoaAsyncSocket revision: ce3e18607fd01079495f86ff6195d8a3ca469f73.
  MqttCocoaAsyncSocket-LICENSE.txt is an unmodified copy of LICENSE.txt.
- Starscream revision: c6bfd1af48efcc9a9ad203665db12375ba6b145a.
  Starscream-LICENSE.txt is an unmodified copy of LICENSE. Its target belongs
  to the optional CocoaMQTTWebSocket product, which this app does not select.
- Swift-LICENSE.txt is the licence published at
  https://www.swift.org/LICENSE.txt, including its Runtime Library Exception.
- Apple-Frameworks.txt identifies the system frameworks and links to Apple's
  software terms. The linked frameworks were checked in the app executable.

Resources/Acknowledgements.json drives the app's offline licence reader.
scripts/VerifyLegalResources.swift checks that every listed document is
present and non-empty in the finished bundle and that dependency versions
match Package.resolved. Review this inventory whenever dependencies change.
