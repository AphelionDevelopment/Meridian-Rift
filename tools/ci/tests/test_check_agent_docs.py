import tempfile
import unittest
from pathlib import Path

from tools.ci.check_agent_docs import REQUIRED_GUIDES, check_repository


class AgentDocumentTests(unittest.TestCase):
	def make_repository(self, root: Path) -> None:
		(root / "AGENTS.md").write_text("\n".join(f"[Guide]({path})" for path in REQUIRED_GUIDES), encoding="utf-8")
		for relative in REQUIRED_GUIDES:
			path = root / relative
			path.parent.mkdir(parents=True, exist_ok=True)
			path.write_text("# Guide\n", encoding="utf-8")
		(root / "docs/agent/source-authority.md").write_text(
			f"Reviewed local revision: `{'a' * 40}`\nReviewed Nova revision: `{'b' * 40}`\nReviewed on: `2026-09-05`\n",
			encoding="utf-8",
		)

	def test_plain_text_does_not_satisfy_required_link(self) -> None:
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			self.make_repository(root)
			(root / "AGENTS.md").write_text("\n".join(REQUIRED_GUIDES), encoding="utf-8")
			self.assertTrue(any("must link" in error for error in check_repository(root)))

	def test_checks_links_in_all_owned_guides(self) -> None:
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			self.make_repository(root)
			(root / "docs/agent/native-subsystem-offload.md").write_text("[Missing](absent.md)\n", encoding="utf-8")
			(root / "docs/agent/build-harness-design.md").write_text("[Missing](absent-design.md)\n", encoding="utf-8")
			errors = check_repository(root)
			self.assertTrue(any("absent.md" in error for error in errors))
			self.assertTrue(any("absent-design.md" in error for error in errors))

	def test_missing_required_guides_are_reported(self) -> None:
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			(root / "AGENTS.md").write_text("# Meridian Rift\n", encoding="utf-8")
			errors = check_repository(root)
			self.assertTrue(any("docs/agent/verification.md" in error for error in errors))

	def test_checked_in_repository_documents_are_consistent(self) -> None:
		root = Path(__file__).resolve().parents[3]
		self.assertEqual(check_repository(root), [])


if __name__ == "__main__":
	unittest.main()
