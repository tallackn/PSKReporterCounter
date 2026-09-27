#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PSK_MODE="${1:-run}"
PSK_BUNDLE="$PWD/build/PSK Reporter Counter.app"
PSK_PROCESS="PSKReporterCounter"
case "$PSK_MODE" in
    run|--debug|--logs|--telemetry|--verify) ;;
    *) printf 'Usage: %s [--debug|--logs|--telemetry|--verify]\n' "$0" >&2; exit 2 ;;
esac

/usr/bin/pkill -x "$PSK_PROCESS" >/dev/null 2>&1 || true
./scripts/build-app.sh

case "$PSK_MODE" in
    --debug)
        exec xcrun lldb -- "$PSK_BUNDLE/Contents/MacOS/$PSK_PROCESS"
        ;;
    *) /usr/bin/open -n "$PSK_BUNDLE" ;;
esac

case "$PSK_MODE" in
    --logs)
        exec /usr/bin/log stream --info --style compact --predicate 'process == "PSKReporterCounter"'
        ;;
    --telemetry)
        exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.tallackn.PSKReporterCounter"'
        ;;
    --verify)
        for PSK_ATTEMPT in {1..20}; do
            if /usr/bin/pgrep -x "$PSK_PROCESS" >/dev/null; then
                printf 'PSK Reporter Counter is running.\n'
                exit 0
            fi
            sleep 0.2
        done
        printf 'The app did not remain running after launch.\n' >&2
        exit 1
        ;;
esac
