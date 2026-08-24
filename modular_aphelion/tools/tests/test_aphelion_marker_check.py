import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from modular_aphelion.tools.aphelion_marker_check import validate_diff


CHECKER_PATH = Path(__file__).resolve().parents[1] / "aphelion_marker_check.py"


def diff(*lines: str, path: str = "code/example.dm") -> str:
	return "\n".join([f"+++ b/{path}", *(f"+{line}" for line in lines)])


class MarkerCheckTests(unittest.TestCase):
	def run_git(self, repository: Path, *arguments: str) -> None:
		subprocess.run(
			["git", *arguments],
			cwd=repository,
			check=True,
			text=True,
			capture_output=True,
		)

	def initialize_diverged_repository(self, repository: Path) -> Path:
		self.run_git(repository, "init", "--initial-branch=main")
		self.run_git(repository, "config", "user.name", "Marker Test")
		self.run_git(repository, "config", "user.email", "marker-test@example.invalid")
		inherited_file = repository / "code" / "inherited.dm"
		inherited_file.parent.mkdir(parents=True)
		inherited_file.write_text("// NOVA EDIT ADDITION - INHERITED\n", encoding="utf-8")
		self.run_git(repository, "add", ".")
		self.run_git(repository, "commit", "-m", "Add inherited Nova marker")
		self.run_git(repository, "branch", "feature")
		inherited_file.write_text("upstream replacement\n", encoding="utf-8")
		self.run_git(repository, "add", ".")
		self.run_git(repository, "commit", "-m", "Advance base branch")
		self.run_git(repository, "switch", "feature")
		return inherited_file

	def run_checker(self, repository: Path) -> subprocess.CompletedProcess[str]:
		return subprocess.run(
			[sys.executable, str(CHECKER_PATH), "--base", "main"],
			cwd=repository,
			check=False,
			text=True,
			capture_output=True,
		)

	def test_accepts_canonical_addition_pair(self) -> None:
		self.assertEqual(validate_diff(diff(
			"// APHELION EDIT ADDITION START - STORAGE_NAVIGATION",
			"new_behavior()",
			"// APHELION EDIT ADDITION END",
		)), [])

	def test_reports_unpaired_and_invalid_markers(self) -> None:
		errors = validate_diff(diff("// APHELION EDIT ADDITION START - bad-id"))
		self.assertEqual({error.code for error in errors}, {"invalid_module_id", "unclosed_marker"})

	def test_rejects_new_nova_marker_outside_nova(self) -> None:
		self.assertEqual(validate_diff(diff("// NOVA EDIT ADDITION START - NEW_FEATURE"))[0].code, "new_nova_marker")

	def test_ignores_context_and_allows_reviewed_nova_sync(self) -> None:
		context = "+++ b/code/example.dm\n // NOVA EDIT ADDITION START - OLD"
		self.assertEqual(validate_diff(context), [])
		self.assertEqual(validate_diff(diff("// NOVA EDIT ADDITION START - SYNC"), allow_nova_sync=True), [])

	def test_cli_ignores_base_tip_changes_after_branching(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = Path(temporary_directory)
			self.initialize_diverged_repository(repository)

			completed = self.run_checker(repository)

			self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

	def test_cli_checks_uncommitted_working_tree_changes(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = Path(temporary_directory)
			inherited_file = self.initialize_diverged_repository(repository)
			inherited_file.write_text(
				"// NOVA EDIT ADDITION - INHERITED\n// NOVA EDIT ADDITION - NEW_FEATURE\n",
				encoding="utf-8",
			)

			completed = self.run_checker(repository)

			self.assertEqual(completed.returncode, 1)
			self.assertIn("new_nova_marker", completed.stdout)


if __name__ == "__main__":
	unittest.main()
