import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("release_source", Path(__file__).resolve().parents[2] / "scripts/release_source.py")
source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(source)


class PublishedSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        self.root = base / "checkout"
        self.remote = str(base / "remote.git")
        self.root.mkdir()
        self.command("git", "init", "--bare", self.remote)
        self.command("git", "init", "-b", "main", str(self.root))
        self.git("config", "user.name", "Release test")
        self.git("config", "user.email", "release@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.root / ".gitignore").write_text("build/\n")
        (self.root / "App.swift").write_text("// Test source\n")
        self.publish()
        self.archive = self.root / "build/Test.xcarchive"
        self.app = self.archive / "Products/Applications/PSK Reporter Counter.app/Contents"
        (self.app / "MacOS").mkdir(parents=True)
        (self.app / "MacOS/PSKReporterCounter").write_bytes(b"test executable")
        (self.app / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "com.tallackn.PSKReporterCounter",
            "CFBundleShortVersionString": "1.2.1", "CFBundleVersion": "12"}))

    def command(self, *arguments):
        return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()

    def git(self, *arguments):
        return self.command("git", "-C", str(self.root), *arguments)

    def publish(self):
        self.git("add", ".")
        self.git("commit", "-m", "Test revision")
        self.git("push", self.remote, "HEAD:refs/heads/main")

    def snapshot(self):
        return source.published_source(self.root, self.remote)

    def record(self):
        return source.record_archive(self.archive, self.snapshot(), self.root, self.remote)

    def verify(self):
        return source.verify_upload(self.archive, self.root, self.remote)

    def test_published_revision_is_recorded_and_verified(self):
        record = self.record()
        self.assertEqual(record["source"]["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(record["archive"]["build"], "12")
        self.assertEqual(self.verify(), record)

    def test_dirty_staged_and_untracked_source_prevent_release(self):
        path = self.root / "App.swift"
        path.write_text("// Changed source\n")
        with self.assertRaisesRegex(source.SourceError, "Commit and publish"):
            self.snapshot()
        self.git("add", "App.swift")
        with self.assertRaisesRegex(source.SourceError, "Commit and publish"):
            self.snapshot()
        self.git("reset", "--hard", "HEAD")
        (self.root / "New.swift").write_text("// Untracked source\n")
        with self.assertRaisesRegex(source.SourceError, "Commit and publish"):
            self.snapshot()

    def test_committed_but_unpublished_source_prevents_release(self):
        (self.root / "App.swift").write_text("// New revision\n")
        self.git("add", "App.swift")
        self.git("commit", "-m", "Not published")
        with self.assertRaisesRegex(source.SourceError, "Publish this exact"):
            self.snapshot()

    def test_remote_advancing_past_checkout_prevents_release(self):
        original = self.git("rev-parse", "HEAD")
        (self.root / "App.swift").write_text("// New revision\n")
        self.publish()
        self.git("reset", "--hard", original)
        with self.assertRaisesRegex(source.SourceError, "Publish this exact"):
            self.snapshot()

    def test_source_change_during_build_cannot_be_recorded(self):
        before = self.snapshot()
        (self.root / "App.swift").write_text("// New revision\n")
        self.publish()
        with self.assertRaisesRegex(source.SourceError, "changed during"):
            source.record_archive(self.archive, before, self.root, self.remote)

    def test_changed_archive_or_missing_record_prevents_upload(self):
        with self.assertRaisesRegex(source.SourceError, "no source record"):
            self.verify()
        self.record()
        (self.app / "MacOS/PSKReporterCounter").write_bytes(b"different executable")
        with self.assertRaisesRegex(source.SourceError, "archived app changed"):
            self.verify()

    def test_archive_from_previous_source_prevents_upload(self):
        self.record()
        (self.root / "App.swift").write_text("// New revision\n")
        self.publish()
        with self.assertRaisesRegex(source.SourceError, "different source revision"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
