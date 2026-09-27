#!/usr/bin/env python3
"""Local archive/upload and internal TestFlight management for this app."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import time
from urllib.parse import urlencode, urlsplit

ROOT = Path(__file__).resolve().parent.parent
APP_ID = "6816545854"
BUNDLE_ID = "com.tallackn.PSKReporterCounter"
GROUP_ID = "cec9d76d-d501-4988-9a11-10b5a0e0205b"
GROUP_NAME = "Baseline UX"
LOCALE = "en-GB"
API = "https://api.appstoreconnect.apple.com"
DEFAULT_CREDENTIALS = Path.home() / "Library/Application Support/PSKReporterCounter/Release/credentials.json"


class ReleaseError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def validate_credentials(path):
    path = path.expanduser().resolve()
    require(not path.is_relative_to(ROOT), "Keep release credentials outside the project.")
    values = json.loads(path.read_text())
    require(re.fullmatch(r"[A-Z0-9]{10}", values["keyID"]), "Invalid API key ID.")
    require(re.fullmatch(r"[0-9a-fA-F-]{36}", values["issuerID"]), "Invalid issuer ID.")
    key = Path(values["privateKeyPath"]).expanduser().resolve()
    require(str(key) == values["privateKeyPath"], "Use an absolute private key path.")
    require(not key.is_relative_to(ROOT), "Keep the private key outside the project.")
    for file in (path, key):
        mode = file.stat()
        require(stat.S_ISREG(mode.st_mode) and mode.st_uid == os.getuid(), "Credentials must be regular files owned by the current user.")
        require(mode.st_mode & 0o077 == 0, "Credential files must have permissions 600 or 400.")
    return path


def ensure_transport():
    source = ROOT / "scripts/AppStoreAPITransport.swift"
    binary = ROOT / "build/AppStoreAPITransport"
    if not binary.exists() or binary.stat().st_mtime < source.stat().st_mtime:
        binary.parent.mkdir(exist_ok=True)
        print("Building the native API transport.", flush=True)
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-O", "-target", "arm64-apple-macosx13.0",
                        "-module-cache-path", str(ROOT / "build/ReleaseModuleCache"),
                        str(source), "-o", str(binary)], check=True)
    return binary


class Client:
    def __init__(self, credentials):
        self.credentials = validate_credentials(credentials)
        self.transport = ensure_transport()

    def request(self, method, path, query=None, body=None):
        url = path if path.startswith("https://") else API + path
        parts = urlsplit(url)
        require(parts.scheme == "https" and parts.netloc == "api.appstoreconnect.apple.com"
                and parts.path.startswith("/v1/") and not parts.fragment, "Unexpected API destination.")
        if query:
            url += "?" + urlencode(query)
        request = {"credentialsFile": str(self.credentials), "method": method, "url": url,
                   "body": json.dumps(body) if body is not None else None}
        for attempt in range(4):
            result = subprocess.run([str(self.transport)], input=json.dumps(request),
                                    capture_output=True, text=True, timeout=55)
            if result.returncode:
                raise ReleaseError("The native API request failed. Check credentials and connectivity.")
            response = json.loads(result.stdout)
            status = response["status"]
            if method == "GET" and (status == 429 or status >= 500) and attempt < 3:
                time.sleep(min(20, 2 ** (attempt + 1)))
                continue
            if not 200 <= status < 300:
                try:
                    errors = json.loads(response["body"]).get("errors", [])
                    detail = "; ".join(e.get("code", "API_ERROR") + ": " + e.get("detail", e.get("title", "")) for e in errors)
                except (ValueError, TypeError):
                    detail = "Unexpected server response."
                raise ReleaseError(f"App Store Connect returned HTTP {status}: {detail[:1200]}")
            return json.loads(response["body"]) if response["body"] else {}

    def all(self, path, query=None):
        result = []
        seen = set()
        while path:
            require(path not in seen, "The API returned a repeated pagination link.")
            seen.add(path)
            page = self.request("GET", path, query=query)
            result.extend(page["data"])
            path = page.get("links", {}).get("next")
            query = None
        return result


def validate_destination(client):
    app = client.request("GET", f"/v1/apps/{APP_ID}")["data"]
    require(app["attributes"]["bundleId"] == BUNDLE_ID, "The app ID does not match this bundle.")
    group = client.request("GET", f"/v1/betaGroups/{GROUP_ID}", query={"include": "app"})["data"]
    require(group["attributes"].get("isInternalGroup") is True, "The destination must be an internal TestFlight group.")
    require(group["attributes"]["name"] == GROUP_NAME, "The TestFlight group name has changed.")
    require(group["relationships"]["app"]["data"]["id"] == APP_ID, "The group belongs to another app.")


def find_build(client, version, number):
    page = client.request("GET", "/v1/builds", query={
        "filter[app]": APP_ID, "filter[version]": number,
        "filter[preReleaseVersion.version]": version, "filter[preReleaseVersion.platform]": "MAC_OS",
        "include": "app,preReleaseVersion", "limit": 200})
    builds = page["data"]
    require(len(builds) <= 1 and not page.get("links", {}).get("next"), "Ambiguous build result.")
    if not builds:
        return None
    build = builds[0]
    require(build["attributes"]["version"] == number, "The build number does not match.")
    require(build["relationships"]["app"]["data"]["id"] == APP_ID, "The build belongs to another app.")
    prerelease_id = build["relationships"]["preReleaseVersion"]["data"]["id"]
    prerelease = next((item for item in page.get("included", [])
                       if item["type"] == "preReleaseVersions" and item["id"] == prerelease_id), None)
    require(prerelease and prerelease["attributes"]["version"] == version
            and prerelease["attributes"]["platform"] == "MAC_OS", "The build version or platform does not match.")
    return build


def wait_for_build(client, version, number, timeout, sleep=time.sleep, clock=time.monotonic):
    deadline, previous = clock() + timeout, None
    while True:
        build = find_build(client, version, number)
        state = build["attributes"]["processingState"] if build else "AWAITING_UPLOAD_RECORD"
        if state != previous:
            print(f"Build {version} ({number}): {state}", flush=True)
            previous = state
        if state == "VALID":
            require(not build["attributes"].get("expired"), "This build has expired.")
            require(build["attributes"].get("usesNonExemptEncryption") is False,
                    "Export compliance needs attention in App Store Connect.")
            return build
        require(state not in ("FAILED", "INVALID"), f"Apple rejected processing: {state}.")
        require(clock() < deadline, "Processing timed out. Resume this upload later without uploading it again.")
        sleep(min(20, max(0, deadline - clock())))


def localisations(client, build_id):
    return client.all(f"/v1/builds/{build_id}/betaBuildLocalizations", {"limit": 200})


def save_notes(client, build_id, notes):
    matches = [item for item in localisations(client, build_id) if item["attributes"]["locale"] == LOCALE]
    require(len(matches) <= 1, "Multiple test-note records have the same locale.")
    if matches:
        item = matches[0]
        if item["attributes"].get("whatsNew") == notes:
            return
        client.request("PATCH", f"/v1/betaBuildLocalizations/{item['id']}", body={"data": {
            "type": "betaBuildLocalizations", "id": item["id"], "attributes": {"whatsNew": notes}}})
    else:
        client.request("POST", "/v1/betaBuildLocalizations", body={"data": {
            "type": "betaBuildLocalizations", "attributes": {"locale": LOCALE, "whatsNew": notes},
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
    require(any(item["attributes"]["locale"] == LOCALE and item["attributes"].get("whatsNew") == notes
                for item in localisations(client, build_id)), "Test notes were not verified after saving.")


def group_has_build(client, build_id):
    # Apple permits one relationship filter here. Destination validation has
    # already checked the exact group's app ownership and internal status.
    groups = client.all("/v1/betaGroups", {"filter[id]": GROUP_ID,
                        "filter[builds]": build_id, "limit": 200})
    return any(item["id"] == GROUP_ID for item in groups)


def add_to_group(client, build_id):
    if group_has_build(client, build_id):
        return
    client.request("POST", f"/v1/betaGroups/{GROUP_ID}/relationships/builds",
                   body={"data": [{"type": "builds", "id": build_id}]})
    require(group_has_build(client, build_id), "The group assignment was not verified. Resume to check again.")


def distribute(client, version, number, notes, timeout):
    require(0 < len(notes.strip()) <= 4000, "Test notes must contain between 1 and 4,000 characters.")
    validate_destination(client)
    build = wait_for_build(client, version, number, timeout)
    save_notes(client, build["id"], notes)
    add_to_group(client, build["id"])
    detail = client.request("GET", f"/v1/builds/{build['id']}/buildBetaDetail")["data"]["attributes"]
    require(detail["internalBuildState"] in ("READY_FOR_BETA_TESTING", "IN_BETA_TESTING"),
            "The build is assigned, but internal testing needs attention: " + detail["internalBuildState"])
    result = {"appID": APP_ID, "version": version, "build": number, "buildID": build["id"],
              "processingState": "VALID", "internalBuildState": detail["internalBuildState"],
              "group": GROUP_NAME, "groupID": GROUP_ID, "notesVerified": True,
              "checkedAt": datetime.datetime.now().astimezone().isoformat()}
    source_record = ROOT / f"build/Archives/PSKReporterCounter-{version}-{number}.xcarchive/PSKSourceRevision.json"
    if source_record.is_file():
        record = json.loads(source_record.read_text())
        require((record["archive"]["version"], record["archive"]["build"]) == (version, number),
                "The source record belongs to another build.")
        result["source"] = record["source"]
    destination = ROOT / f"build/testflight-{version}-{number}-result.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return result


def release_version():
    text = (ROOT / "Configuration/AppStore.xcconfig").read_text()
    def value(name):
        match = re.search(r"^" + name + r"\s*=\s*([0-9.]+)\s*$", text, re.M)
        require(match is not None, f"Missing {name} in AppStore.xcconfig.")
        return match.group(1)
    return value("MARKETING_VERSION"), value("CURRENT_PROJECT_VERSION")


def run_stage(name, command, directory):
    print(name + ".", flush=True)
    log = directory / (name.lower().replace(" ", "-") + ".log")
    with log.open("w") as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    require(result.returncode == 0, f"{name} failed. See {log}.")


def archive_manifest(version, number):
    archive = ROOT / "build/PSKReporterCounter.xcarchive"
    app = archive / "Products/Applications/PSK Reporter Counter.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    require((info["CFBundleShortVersionString"], info["CFBundleVersion"], info["CFBundleIdentifier"])
            == (version, number, BUNDLE_ID), "The archive does not match the requested release.")
    frozen = ROOT / f"build/Archives/PSKReporterCounter-{version}-{number}.xcarchive"
    require(not frozen.exists(), f"An archive already exists for build {number}: {frozen}")
    frozen.parent.mkdir(exist_ok=True)
    shutil.copytree(archive, frozen, symlinks=True)
    files = []
    for folder in ("App", "Resources", "Configuration", "PSKReporterCounter.xcodeproj", "scripts", "Tests", "ReleaseNotes", "ThirdPartyLicences"):
        files.extend(path for path in (ROOT / folder).rglob("*") if path.is_file() and "__pycache__" not in path.parts and "xcuserdata" not in path.parts)
    files.extend(ROOT / name for name in ("Package.swift", "Package.resolved", "LICENSE"))
    manifest = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(files)}
    (ROOT / f"build/testflight-build-{number}-source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", type=Path, default=DEFAULT_CREDENTIALS)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check", help="Verify authentication, bundle identity and internal group")
    status = commands.add_parser("status", help="Read one exact macOS build")
    status.add_argument("--version", required=True)
    status.add_argument("--build", required=True)
    for name in ("distribute", "release"):
        command = commands.add_parser(name)
        command.add_argument("--notes-file", required=True, type=Path)
        command.add_argument("--timeout", type=int, default=1800)
        if name == "release":
            command.add_argument("--resume", action="store_true", help="Only finish TestFlight setup for an already uploaded build")
        else:
            command.add_argument("--version", required=True)
            command.add_argument("--build", required=True)
    args = parser.parse_args()
    client = Client(args.credentials)
    if args.command == "check":
        validate_destination(client)
        print(f"API access verified for {BUNDLE_ID} and internal group {GROUP_NAME}.")
    elif args.command == "status":
        validate_destination(client)
        build = find_build(client, args.version, args.build)
        require(build is not None, "No matching build exists.")
        attributes = {key: build["attributes"].get(key) for key in
                      ("version", "uploadedDate", "processingState", "expired", "usesNonExemptEncryption")}
        print(json.dumps({"id": build["id"], "attributes": attributes,
                          "assignedToBaselineUX": group_has_build(client, build["id"])}, indent=2))
    else:
        notes = args.notes_file.read_text().strip()
        require(0 < len(notes) <= 4000, "Test notes must contain between 1 and 4,000 characters.")
        if args.command == "release":
            version, number = release_version()
            validate_destination(client)
            if not args.resume:
                require(find_build(client, version, number) is None, "That build already exists. Increment the build number or use --resume.")
                frozen = ROOT / f"build/Archives/PSKReporterCounter-{version}-{number}.xcarchive"
                require(not frozen.exists(), "A local archive already exists for this build. Inspect it before creating another release.")
                directory = ROOT / f"build/Releases/{version}-{number}"
                directory.mkdir(parents=True, exist_ok=True)
                source = directory / "source.json"
                run_stage("Published source check", ["python3", "scripts/release_source.py", "check", "--output", str(source)], directory)
                run_stage("Release tooling checks", ["python3", "-m", "unittest", "discover", "-s", "Tests/ReleaseToolsTests"], directory)
                run_stage("Core tests", ["bash", "scripts/test.sh"], directory)
                run_stage("Popover placement checks", ["bash", "scripts/check-popover-placement.sh"], directory)
                run_stage("Popover anchor check", ["bash", "scripts/check-popover-anchor.sh"], directory)
                run_stage("Archive", ["bash", "scripts/archive-app.sh"], directory)
                run_stage("Record archive source", ["python3", "scripts/release_source.py", "record",
                          "--archive", str(ROOT / "build/PSKReporterCounter.xcarchive"), "--source", str(source)], directory)
                archive_manifest(version, number)
                run_stage("Upload", ["bash", "scripts/distribute-app.sh", "--upload"], directory)
            distribute(client, version, number, notes, args.timeout)
        else:
            distribute(client, args.version, args.build, notes, args.timeout)


if __name__ == "__main__":
    try:
        main()
    except (ReleaseError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)
