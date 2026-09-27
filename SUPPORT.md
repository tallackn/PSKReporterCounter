# PSK Reporter Counter support

Developed and maintained by Nathan Tallack (ZL2NU).

For help or privacy enquiries, [open an issue on GitHub](https://github.com/tallackn/PSKReporterCounter/issues). You can also read existing issues without signing in. Posting requires a GitHub account. Issues are public, so omit private contact details, credentials and unrelated information from screenshots or logs.

## Start monitoring

1. Open PSK Reporter Counter and enter the transmitting callsign in Settings.
2. Choose a window length, band and mode. The defaults are 15 minutes, All bands and All modes.
3. Leave **Count unique stations** enabled to count each receiving callsign once, or turn it off to count all reports.
4. Select **Save and Start**. The count updates as reports arrive.

Left-click the menu bar count to open or close the graphs. Right-click or Control-click for Settings, Reconnect, About, Help and Quit. The Help window contains a searchable offline guide.

## A zero count

The app collects live reports from the time it connects. It does not download older reports. Confirm the full transmitting callsign, including any portable suffix, and try All bands and All modes. Leave the app running while reports arrive.

Reports are counted by arrival time at the app. PSK Reporter's map may show a different total because it includes older reports and uses reception times. A receiving station must upload its report before it can appear here.

## A warning or stopped symbol

Hover over the menu bar item for a summary, then open Settings for details. Check your internet connection and that your network allows secure access to `mqtt.pskreporter.info` on TCP port 1884. The app retries failed connections automatically. **Reconnect** begins a fresh window.

After an interruption, a warning remains until a full uninterrupted window has been collected. The graphs can update during this recovery. A stopped symbol means monitoring is paused or the callsign is missing or invalid.

## Report a problem

Include the app version and build from About, your macOS version, the steps taken, and what happened. Where useful, include a screenshot limited to the app and the relevant Settings status. Review it for personal information before posting. Do not post authentication keys or passwords.

## Further information

- [Privacy policy](PRIVACY.md)
- [Source, local build and installation instructions](README.md)
- [PSK Reporter MQTT service](https://www.mqtt.pskreporter.info/)

PSK Reporter Counter is an independent client. Availability and delivery delays of the external feed are outside the app developer's control.
