import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("asc", Path(__file__).resolve().parents[2] / "scripts/app_store_connect.py")
asc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(asc)


class FakeApple:
    """A small stateful server fixture for the documented JSON API resources."""
    def __init__(self):
        self.writes = []
        self.bundle_id = asc.BUNDLE_ID
        self.internal = True
        self.group_app = asc.APP_ID
        self.build_app = asc.APP_ID
        self.platform = "MAC_OS"
        self.states = ["VALID"]
        self.encryption = False
        self.expired = False
        self.assigned = False
        self.notes = []
        self.duplicate_build = False
        self.drop_note_writes = False

    def request(self, method, path, query=None, body=None):
        if method != "GET":
            self.writes.append((method, path, copy.deepcopy(body)))
        if path == f"/v1/apps/{asc.APP_ID}":
            return {"data": {"id": asc.APP_ID, "attributes": {"bundleId": self.bundle_id}}}
        if path == f"/v1/betaGroups/{asc.GROUP_ID}":
            return {"data": {"id": asc.GROUP_ID, "attributes": {"name": asc.GROUP_NAME, "isInternalGroup": self.internal},
                             "relationships": {"app": {"data": {"id": self.group_app}}}}}
        if path == "/v1/builds":
            assert query["filter[app]"] == asc.APP_ID
            assert query["filter[version]"] == "11"
            assert query["filter[preReleaseVersion.version]"] == "1.2.1"
            assert query["filter[preReleaseVersion.platform]"] == "MAC_OS"
            state = self.states.pop(0) if len(self.states) > 1 else self.states[0]
            if state == "MISSING":
                return {"data": []}
            build = {"type": "builds", "id": "build-11", "attributes": {
                "version": "11", "processingState": state, "expired": self.expired,
                "usesNonExemptEncryption": self.encryption}, "relationships": {
                "app": {"data": {"id": self.build_app}}, "preReleaseVersion": {"data": {"id": "version-1"}}}}
            return {"data": [build, build] if self.duplicate_build else [build], "included": [{
                "type": "preReleaseVersions", "id": "version-1", "attributes": {"version": "1.2.1", "platform": self.platform}}]}
        if path == "/v1/builds/build-11/betaBuildLocalizations":
            return {"data": copy.deepcopy(self.notes)}
        if path in ("/v1/betaBuildLocalizations", "/v1/betaBuildLocalizations/notes-1"):
            assert method in ("POST", "PATCH")
            if not self.drop_note_writes:
                if method == "POST":
                    assert body["data"]["relationships"]["build"]["data"]["id"] == "build-11"
                self.notes = [{"type": "betaBuildLocalizations", "id": "notes-1", "attributes": {
                    "locale": "en-GB", "whatsNew": body["data"]["attributes"]["whatsNew"]}}]
            return {}
        if path == "/v1/betaGroups":
            assert query["filter[builds]"] == "build-11"
            assert query["filter[id]"] == asc.GROUP_ID
            assert "filter[app]" not in query
            return {"data": [{"id": asc.GROUP_ID}] if self.assigned else []}
        if path == f"/v1/betaGroups/{asc.GROUP_ID}/relationships/builds":
            assert body == {"data": [{"type": "builds", "id": "build-11"}]}
            self.assigned = True
            return {}
        if path == "/v1/builds/build-11/buildBetaDetail":
            return {"data": {"attributes": {"internalBuildState": "IN_BETA_TESTING"}}}
        raise AssertionError((method, path, query, body))

    def all(self, path, query=None):
        return self.request("GET", path, query)["data"]


class DistributionTests(unittest.TestCase):
    def run_distribution(self, server, notes="Graph placement check."):
        with tempfile.TemporaryDirectory() as directory, patch.object(asc, "ROOT", Path(directory)):
            return asc.distribute(server, "1.2.1", "11", notes, 1)

    def test_distribution_and_repeat_are_idempotent(self):
        server = FakeApple()
        result = self.run_distribution(server)
        self.assertTrue(server.assigned)
        self.assertTrue(result["notesVerified"])
        self.assertEqual(len(server.writes), 2)
        self.run_distribution(server)
        self.assertEqual(len(server.writes), 2)

    def test_changed_notes_update_existing_record(self):
        server = FakeApple()
        self.run_distribution(server)
        self.run_distribution(server, "Updated test instructions.")
        self.assertEqual([item[0] for item in server.writes], ["POST", "POST", "PATCH"])
        self.assertEqual(server.notes[0]["attributes"]["whatsNew"], "Updated test instructions.")

    def test_different_app_or_external_group_blocks_all_writes(self):
        for attribute, value in (("bundle_id", "another.bundle"), ("group_app", "another-app"),
                                 ("build_app", "another-app"), ("internal", False), ("platform", "IOS")):
            with self.subTest(attribute=attribute):
                server = FakeApple()
                setattr(server, attribute, value)
                with self.assertRaises(asc.ReleaseError):
                    self.run_distribution(server)
                self.assertEqual(server.writes, [])

    def test_failed_or_invalid_processing_blocks_all_writes(self):
        for state in ("FAILED", "INVALID"):
            with self.subTest(state=state):
                server = FakeApple()
                server.states = [state]
                with self.assertRaises(asc.ReleaseError):
                    self.run_distribution(server)
                self.assertEqual(server.writes, [])

    def test_expiry_and_unresolved_encryption_block_writes(self):
        for attribute, value in (("expired", True), ("encryption", None), ("encryption", True)):
            with self.subTest(attribute=attribute, value=value):
                server = FakeApple()
                setattr(server, attribute, value)
                with self.assertRaises(asc.ReleaseError):
                    self.run_distribution(server)
                self.assertEqual(server.writes, [])

    def test_missing_then_processing_then_valid(self):
        server = FakeApple()
        server.states = ["MISSING", "PROCESSING", "VALID"]
        clock = [0]
        build = asc.wait_for_build(server, "1.2.1", "11", 100,
            sleep=lambda seconds: clock.__setitem__(0, clock[0] + seconds), clock=lambda: clock[0])
        self.assertEqual(build["id"], "build-11")
        self.assertEqual(clock[0], 40)

    def test_processing_timeout_has_no_writes(self):
        server = FakeApple()
        server.states = ["PROCESSING"]
        clock = [0]
        with self.assertRaisesRegex(asc.ReleaseError, "Resume"):
            asc.wait_for_build(server, "1.2.1", "11", 1,
                sleep=lambda seconds: clock.__setitem__(0, clock[0] + seconds), clock=lambda: clock[0])
        self.assertEqual(server.writes, [])

    def test_ambiguous_build_blocks_writes(self):
        server = FakeApple()
        server.duplicate_build = True
        with self.assertRaisesRegex(asc.ReleaseError, "Ambiguous"):
            self.run_distribution(server)
        self.assertEqual(server.writes, [])

    def test_note_save_must_be_verified_before_group_assignment(self):
        server = FakeApple()
        server.drop_note_writes = True
        with self.assertRaisesRegex(asc.ReleaseError, "not verified"):
            self.run_distribution(server)
        self.assertFalse(server.assigned)

    def test_invalid_notes_have_no_writes(self):
        for notes in (" ", "a" * 4001):
            with self.subTest(length=len(notes)):
                server = FakeApple()
                with self.assertRaises(asc.ReleaseError):
                    self.run_distribution(server, notes)
                self.assertEqual(server.writes, [])

    def test_resume_skips_archive_and_upload(self):
        server = FakeApple()
        with tempfile.TemporaryDirectory() as directory:
            notes = Path(directory) / "notes.txt"
            notes.write_text("Graph placement check.")
            with patch.object(asc, "ROOT", Path(directory)), patch.object(asc, "Client", return_value=server), \
                 patch.object(asc, "release_version", return_value=("1.2.1", "11")), \
                 patch.object(asc, "run_stage") as run, \
                 patch.object(asc.sys, "argv", ["asc", "release", "--resume", "--notes-file", str(notes)]):
                asc.main()
                run.assert_not_called()


class CredentialsTests(unittest.TestCase):
    def test_permissions_and_location(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            key = root / "key.p8"
            key.write_text("Not a real key; validation reads file metadata only.")
            config = root / "credentials.json"
            config.write_text(json.dumps({"keyID": "ABCDEFGHIJ", "issuerID": "00000000-0000-0000-0000-000000000000",
                                          "privateKeyPath": str(key.resolve())}))
            config.chmod(0o600)
            key.chmod(0o600)
            self.assertEqual(asc.validate_credentials(config), config.resolve())
            key.chmod(0o644)
            with self.assertRaisesRegex(asc.ReleaseError, "permissions"):
                asc.validate_credentials(config)
            key.chmod(0o600)
            with patch.object(asc, "ROOT", root.resolve()), self.assertRaisesRegex(asc.ReleaseError, "outside"):
                asc.validate_credentials(config)


if __name__ == "__main__":
    unittest.main()
