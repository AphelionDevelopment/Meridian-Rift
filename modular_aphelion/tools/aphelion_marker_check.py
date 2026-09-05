#!/usr/bin/env python3
"""Validate marker regressions in a full-context diff, preserving legacy debt."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass

MODULE_ID = r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*"
START = re.compile(rf"APHELION EDIT (ADDITION|REMOVAL) START - (?P<module>\S+)")
END = re.compile(r"APHELION EDIT (ADDITION|REMOVAL) END\b")
CHANGE = re.compile(rf"APHELION EDIT CHANGE - (?P<module>{MODULE_ID}) - ORIGINAL: .+")
IGNORED_MARKER_SUFFIXES = (".md", ".py")


@dataclass(frozen=True)
class MarkerError:
	code: str
	path: str
	line: int
	message: str


def validate_markers(path: str, lines: list[tuple[int, str]]) -> list[MarkerError]:
	"""Check syntax and pairing for one side of a file diff."""
	errors: list[MarkerError] = []
	open_markers: list[tuple[str, str, int]] = []
	for line_number, line in lines:
		start = START.search(line)
		if start:
			module = start.group("module")
			kind = start.group(1)
			if not re.fullmatch(MODULE_ID, module):
				errors.append(MarkerError("invalid_module_id", path, line_number, f"invalid module ID: {module}"))
			open_markers.append((kind, module, line_number))
			continue
		end = END.search(line)
		if end:
			kind = end.group(1)
			if not open_markers or open_markers[-1][0] != kind:
				errors.append(MarkerError("mismatched_marker", path, line_number, f"unmatched {kind} end marker"))
			else:
				open_markers.pop()
			continue
		if "APHELION EDIT CHANGE" in line and not CHANGE.search(line):
			errors.append(MarkerError("invalid_change_marker", path, line_number, "change marker requires module ID and ORIGINAL text"))
		elif "APHELION EDIT" in line and not CHANGE.search(line):
			errors.append(MarkerError("invalid_marker", path, line_number, "marker requires canonical kind, boundary, and module ID"))
	for kind, module, opened_at in open_markers:
		errors.append(MarkerError("unclosed_marker", path, opened_at, f"unclosed {kind} marker for {module}"))
	return errors


def validate_diff(diff_text: str, *, allow_nova_sync: bool = False) -> list[MarkerError]:
	"""Report new errors; full context is required for unchanged pairing endpoints."""
	errors: list[MarkerError] = []
	path = "<diff>"
	old_lines: list[tuple[int, str]] = []
	new_lines: list[tuple[int, str]] = []
	added_lines: list[tuple[int, str]] = []
	old_number = new_number = 0

	def finish_file() -> None:
		if path.endswith(IGNORED_MARKER_SUFFIXES):
			return
		old_text = dict(old_lines)
		new_text = dict(new_lines)
		baseline = Counter(
			(error.code, error.message, old_text[error.line])
			for error in validate_markers(path, old_lines)
		)
		for error in validate_markers(path, new_lines):
			key = (error.code, error.message, new_text[error.line])
			if baseline[key]:
				baseline[key] -= 1
			else:
				errors.append(error)
		if not path.startswith("modular_nova/") and not allow_nova_sync:
			for number, line in added_lines:
				if "NOVA EDIT" in line:
					errors.append(MarkerError("new_nova_marker", path, number, "new Meridian work must use APHELION EDIT"))

	for raw_line in diff_text.splitlines():
		if raw_line.startswith("+++ "):
			finish_file()
			path = raw_line[6:] if raw_line.startswith("+++ b/") else raw_line[4:]
			old_lines.clear()
			new_lines.clear()
			added_lines.clear()
			old_number = new_number = 0
			continue
		if raw_line.startswith("@@"):
			match = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw_line)
			if match:
				old_number, new_number = (int(value) - 1 for value in match.groups())
			continue
		if raw_line.startswith("--- ") or not raw_line.startswith((" ", "+", "-")):
			continue
		line = raw_line[1:]
		if raw_line[0] in " -":
			old_number += 1
			old_lines.append((old_number, line))
		if raw_line[0] in " +":
			new_number += 1
			new_lines.append((new_number, line))
		if raw_line.startswith("+"):
			added_lines.append((new_number, line))
	finish_file()
	return errors


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--base")
	parser.add_argument("--allow-nova-sync", action="store_true")
	args = parser.parse_args()
	if args.base:
		merge_base = subprocess.run(
			["git", "merge-base", args.base, "HEAD"],
			text=True,
			encoding="utf-8",
			errors="replace",
			capture_output=True,
			check=False,
		)
		if merge_base.returncode:
			print(merge_base.stderr, file=sys.stderr)
			return merge_base.returncode
		completed = subprocess.run(
			["git", "-c", "core.quotePath=false", "diff", "--no-ext-diff", "--unified=2147483647", merge_base.stdout.strip(), "--"],
			text=True,
			encoding="utf-8",
			errors="replace",
			capture_output=True,
			check=False,
		)
		if completed.returncode:
			print(completed.stderr, file=sys.stderr)
			return completed.returncode
		diff_text = completed.stdout
	else:
		diff_text = sys.stdin.read()
	errors = validate_diff(diff_text, allow_nova_sync=args.allow_nova_sync)
	for error in errors:
		print(f"{error.path}:{error.line}: {error.code}: {error.message}")
	return 1 if errors else 0


if __name__ == "__main__":
	sys.exit(main())
