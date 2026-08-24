import tempfile
import unittest
from pathlib import Path

from tools.ci.check_agent_docs import check_repository


class AgentDocumentTests(unittest.TestCase):
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
