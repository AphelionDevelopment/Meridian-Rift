#!/usr/bin/env python3
"""Validate Meridian-Rift's local agent-document routing."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED_GUIDES = (
	"docs/agent/README.md",
	"docs/agent/source-authority.md",
	"docs/agent/placement-and-markers.md",
	"docs/agent/verification.md",
	"docs/agent/meridian-mcp.md",
	"docs/agent/generated-content.md",
	"docs/agent/upstream-drift.md",
)
LINK = re.compile(r"\[[^]]+\]\(([^)]+)\)")


def check_repository(root: Path) -> list[str]:
	errors: list[str] = []
	agents = root / "AGENTS.md"
	if not agents.is_file():
		errors.append("missing AGENTS.md")
		agent_text = ""
	else:
		agent_text = agents.read_text(encoding="utf-8")
	for relative in REQUIRED_GUIDES:
		path = root / relative
		if not path.is_file():
			errors.append(f"missing {relative}")
		if relative not in agent_text:
			errors.append(f"AGENTS.md must link {relative}")

	checked = [agents, *(root / relative for relative in REQUIRED_GUIDES)]
	for source in checked:
		if not source.is_file():
			continue
		for target in LINK.findall(source.read_text(encoding="utf-8")):
			if "://" in target or target.startswith("#") or target.startswith("mailto:"):
				continue
			path_target = target.split("#", 1)[0]
			if path_target and not (source.parent / path_target).resolve().exists():
				errors.append(f"broken local link in {source.relative_to(root)}: {target}")

	authority = root / "docs/agent/source-authority.md"
	if authority.is_file():
		text = authority.read_text(encoding="utf-8")
		for label in ("Reviewed local revision", "Reviewed Nova revision"):
			if not re.search(rf"{label}: `[0-9a-f]{{40}}`", text):
				errors.append(f"{authority.relative_to(root)} lacks full {label}")
		if not re.search(r"Reviewed on: `\d{4}-\d{2}-\d{2}`", text):
			errors.append(f"{authority.relative_to(root)} lacks Reviewed on date")
	return errors


def main() -> int:
	root = Path(__file__).resolve().parents[2]
	errors = check_repository(root)
	for error in errors:
		print(error)
	return 1 if errors else 0


if __name__ == "__main__":
	sys.exit(main())
