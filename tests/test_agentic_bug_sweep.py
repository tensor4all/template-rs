import json
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROMPT_PATH = REPO_ROOT / "ai" / "agentic-bug-sweep.md"
SCHEMA_PATH = REPO_ROOT / "ai" / "agentic-bug-sweep.schema.json"
SOURCE_SCRIPT = REPO_ROOT / "scripts" / "agentic-bug-sweep.sh"


class AgenticBugSweepTests(unittest.TestCase):
    def test_prompt_and_schema_contract(self) -> None:
        self.assertTrue(PROMPT_PATH.is_file(), msg=f"missing prompt file: {PROMPT_PATH}")
        prompt = PROMPT_PATH.read_text(encoding="utf-8")
        self.assertIn("open bug issues", prompt)
        self.assertIn("prior bug-sweep reports", prompt)
        self.assertIn("related_issue_numbers", prompt)

        self.assertTrue(SCHEMA_PATH.is_file(), msg=f"missing schema file: {SCHEMA_PATH}")
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))

        action_enum = schema["properties"]["action"]["enum"]
        self.assertEqual(action_enum, ["create", "update", "merge", "none"])
        self.assertIn("related_issue_numbers", schema["properties"])
        self.assertIn("if", schema["allOf"][0])

    def test_help_path(self) -> None:
        result = subprocess.run(
            ["bash", str(SOURCE_SCRIPT), "--help"],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, msg=f"stdout={result.stdout}\nstderr={result.stderr}")
        self.assertIn("--iterations", result.stdout)
        self.assertIn("--max-consecutive-none", result.stdout)
        self.assertIn("--repo", result.stdout)
        self.assertIn("--workdir", result.stdout)


if __name__ == "__main__":
    unittest.main()
