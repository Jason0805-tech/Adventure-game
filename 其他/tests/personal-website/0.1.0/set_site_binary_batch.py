"""Update the temporary, per-batch source ignore list for Sites size limits."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
files = sys.argv[2:]
path = root / ".gitignore"
base = path.read_text().split("\n# Temporary small-push batches")[0].rstrip()
if files:
    rules = "\n".join(
        f"!dist/games/forest-wanderer/data/{name}" for name in files
    )
    base += (
        "\n\n# Temporary small-push batches; removed in the final source commit.\n"
        "dist/games/forest-wanderer/data/*.bin\n"
        f"{rules}\n"
    )
path.write_text(base)
