#!/usr/bin/env python3
"""Require published, unchanged source before an App Store Connect upload."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "https://github.com/tallackn/PSKReporterCounter"
RECORD = "PSKSourceRevision.json"


class SourceError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise SourceError(message)


def git(root, *arguments):
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True, timeout=60).strip()


def published_source(root=ROOT, repository=REPOSITORY):
    require(Path(git(root, "rev-parse", "--show-toplevel")).resolve() == root.resolve(),
            "Run the release from this project's own Git checkout.")
    require(not git(root, "status", "--porcelain", "--untracked-files=all"),
            "Commit and publish all source changes before releasing.")
    commit = git(root, "rev-parse", "HEAD")
    tree = git(root, "rev-parse", "HEAD^{tree}")
    remote = git(root, "ls-remote", repository, "refs/heads/main").split()
    require(len(remote) == 2 and remote[0] == commit,
            "Publish this exact source revision to tallackn/PSKReporterCounter main before uploading.")
    return {"repository": repository, "commit": commit, "tree": tree,
            "url": f"{repository}/commit/{commit}"}


def archive_fingerprint(archive):
    app = archive / "Products/Applications/PSK Reporter Counter.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    require(info["CFBundleIdentifier"] == "com.tallackn.PSKReporterCounter", "Unexpected archived app.")
    # Hash the app's files as well as symlink targets without following links
    # outside the bundle. Signing resources and the executable are included.
    files = {}
    for path in sorted(app.rglob("*")):
        relative = path.relative_to(app).as_posix()
        if path.is_symlink():
            files[relative] = {"symlink": str(path.readlink())}
        elif path.is_file():
            files[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {"version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
            "files": files}


def record_archive(archive, before, root=ROOT, repository=REPOSITORY):
    current = published_source(root, repository)
    require(current == before, "The source changed during the build. Rebuild from the published revision.")
    record = {"source": current, "archive": archive_fingerprint(archive)}
    (archive / RECORD).write_text(json.dumps(record, indent=2) + "\n")
    return record


def verify_upload(archive, root=ROOT, repository=REPOSITORY):
    path = archive / RECORD
    require(path.is_file(), "This archive has no source record. Use scripts/release-testflight.sh to create it.")
    record = json.loads(path.read_text())
    require(record["source"] == published_source(root, repository),
            "The archive belongs to a different source revision. Rebuild before uploading.")
    require(record["archive"] == archive_fingerprint(archive),
            "The archived app changed after source verification. Rebuild before uploading.")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("check")
    check.add_argument("--output", type=Path, required=True)
    record = commands.add_parser("record")
    record.add_argument("--archive", type=Path, required=True)
    record.add_argument("--source", type=Path, required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("--archive", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "check":
        source = published_source()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(source, indent=2) + "\n")
    elif args.command == "record":
        source = record_archive(args.archive, json.loads(args.source.read_text()))["source"]
    else:
        source = verify_upload(args.archive)["source"]
    print(f"Published source verified: {source['url']}")


if __name__ == "__main__":
    try:
        main()
    except (SourceError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Source verification stopped: {error}", file=sys.stderr)
        sys.exit(1)
