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

	def test_rejects_malformed_marker_prefixes(self) -> None:
		for marker in ("ADDITION START", "REMOVAL START -", "ADDITION STOP"):
			with self.subTest(marker=marker):
				self.assertTrue(validate_diff(diff(f"// APHELION EDIT {marker}")))

	def test_context_advances_reported_line_numbers(self) -> None:
		errors = validate_diff("+++ b/code/example.dm\n@@ -10 +10,2 @@\n unchanged()\n+// NOVA EDIT ADDITION START - NEW")
		self.assertEqual(errors[0].line, 11)

	def test_changed_start_uses_unchanged_end(self) -> None:
		self.assertEqual(validate_diff("\n".join((
			"+++ b/code/example.dm", "@@ -1,3 +1,3 @@",
			"-// APHELION EDIT ADDITION START - OLD",
			"+// APHELION EDIT ADDITION START - NEW",
			" code()", " // APHELION EDIT ADDITION END",
		))), [])

	def test_deleted_end_is_reported(self) -> None:
		errors = validate_diff("\n".join((
			"+++ b/code/example.dm", "@@ -1,3 +1,2 @@",
			" // APHELION EDIT ADDITION START - OLD", " code()",
			"-// APHELION EDIT ADDITION END",
		)))
		self.assertEqual([error.code for error in errors], ["unclosed_marker"])

	def test_unchanged_legacy_marker_errors_are_not_reported(self) -> None:
		self.assertEqual(validate_diff("\n".join((
			"+++ b/code/example.dm", "@@ -1,2 +1,2 @@",
			" // APHELION EDIT ADDITION START", "-old_code()", "+new_code()",
		))), [])

	def test_modified_malformed_marker_is_not_hidden_by_legacy_error(self) -> None:
		errors = validate_diff("\n".join((
			"+++ b/code/example.dm", "@@ -1 +1 @@",
			"-// APHELION EDIT ADDITION START", "+// APHELION EDIT REMOVAL STOP",
		)))
		self.assertEqual([error.code for error in errors], ["invalid_marker"])

	def test_cli_validates_modified_existing_pairs(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = Path(temporary_directory)
			inherited_file = self.initialize_diverged_repository(repository)
			original = "// APHELION EDIT ADDITION START - OLD\ncode()\n// APHELION EDIT ADDITION END\n"
			inherited_file.write_text(original, encoding="utf-8")
			self.run_git(repository, "add", ".")
			self.run_git(repository, "commit", "-m", "Add canonical pair")
			self.run_git(repository, "branch", "-f", "main", "HEAD")
			inherited_file.write_text(original.replace("OLD", "NEW"), encoding="utf-8")
			completed = self.run_checker(repository)
			self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
			inherited_file.write_text(original.rsplit("//", 1)[0], encoding="utf-8")
			completed = self.run_checker(repository)
			self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
			self.assertIn("unclosed_marker", completed.stdout)

	def test_rejects_new_nova_marker_outside_nova(self) -> None:
		self.assertEqual(validate_diff(diff("// NOVA EDIT ADDITION START - NEW_FEATURE"))[0].code, "new_nova_marker")

	def test_ignores_context_and_allows_reviewed_nova_sync(self) -> None:
		context = "+++ b/code/example.dm\n // NOVA EDIT ADDITION START - OLD"
		self.assertEqual(validate_diff(context), [])
		self.assertEqual(validate_diff(diff("// NOVA EDIT ADDITION START - SYNC"), allow_nova_sync=True), [])

	def test_ignores_marker_examples_in_documentation_and_python(self) -> None:
		for path in ("docs/example.md", "tools/example.py"):
			with self.subTest(path=path):
				self.assertEqual(validate_diff(diff("// NOVA EDIT ADDITION START - EXAMPLE", path=path)), [])

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
