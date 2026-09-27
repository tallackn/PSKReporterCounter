# Privacy policy

PSK Reporter Counter is developed by Nathan Tallack (ZL2NU). This policy covers version 2.0 and was last updated on 27 September 2026.

## Information on your Mac

The app stores your chosen transmitting callsign and preferences on your Mac. Reception reports are held in memory for the selected sliding window. Older reports expire, and quitting the app clears this report history. The app does not upload your reception history to the developer.

The app does not request access to your contacts, microphone, camera, location services or personal documents. It has no account system, advertising or analytics SDK. Basic connection, lifecycle and error events may appear in macOS diagnostic logs. The app does not send these logs to the developer.

## The live feed

Monitoring connects directly to the independently operated [PSK Reporter MQTT feed](https://www.mqtt.pskreporter.info/) using an encrypted connection. The feed is provided by Tom M0LTE and distributes reception data from PSK Reporter, operated by Philip Gladstone.

To supply matching reports, the feed receives the transmitting callsign, band and mode you select. The connection also exposes your IP address and a randomly generated MQTT connection identifier to the feed operator. The callsign can identify an amateur radio operator and does not have to be your own callsign. No password or PSK Reporter account is required.

Nathan Tallack does not operate this feed and cannot control or delete its server logs. The feed's public documentation does not specify how long it retains connection or subscription information. This policy therefore makes no promise that the feed discards those details immediately. Consult the feed operator through the discussion link on its website for information about its practices.

## Your choices

Use **Stop Monitoring** or quit the app to end the live connection. A saved valid callsign starts monitoring again on the next launch. You can change the callsign and filters in Settings, and disable automatic launch at login there.

The app has no developer account or server profile to delete. Removing the app does not necessarily remove preferences retained by macOS. Reception history is cleared when the app quits.

## External links and support

Opening links uses your browser. GitHub, PSK Reporter and other destinations apply their own privacy practices. Apple's distribution, crash reporting and diagnostic services are governed by your Apple settings and Apple's privacy information.

Support and privacy enquiries can be raised through [GitHub Issues](https://github.com/tallackn/PSKReporterCounter/issues). Issues are public: include only information you are comfortable publishing. Do not include passwords, private keys, personal contact details or unredacted diagnostic logs. A GitHub account is required to post an issue. Information you choose to publish there is handled by GitHub under its [privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Changes

Material changes to these practices will be described here with an updated date. This policy is versioned with the public source code.
