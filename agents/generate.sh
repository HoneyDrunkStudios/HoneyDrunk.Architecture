#!/usr/bin/env bash
# Agent Generator — ADR-0004: Tool-Agnostic Agent Definitions
# Reads canonical agents from agents/canonical/ and generates into .claude/agents/.
# Copilot discovers agents from .claude/agents/ automatically, so no separate
# Copilot output is needed. Use --target copilot if a future tool requires
# .github/agents/ output.
#
# Usage:
#   bash agents/generate.sh                    # Generate into .claude/agents/
#   bash agents/generate.sh --target copilot   # Generate into .github/agents/ only
#   bash agents/generate.sh --target all       # Generate into both directories
#   bash agents/generate.sh --check            # Verify generated files are up-to-date (CI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_DIR="$SCRIPT_DIR/canonical"
MAPPINGS_FILE="$SCRIPT_DIR/tool-mappings.json"
CLAUDE_DIR="$REPO_ROOT/.claude/agents"
COPILOT_DIR="$REPO_ROOT/.github/agents"

CHECK_MODE=false
TARGET="claude"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_MODE=true; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ "$TARGET" != "all" && "$TARGET" != "copilot" && "$TARGET" != "claude" ]]; then
  echo "Error: --target must be 'all', 'copilot', or 'claude'"
  exit 1
fi

# Verify dependencies
if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

# Ensure output directories exist based on target
if [[ "$TARGET" == "all" || "$TARGET" == "claude" ]]; then
  mkdir -p "$CLAUDE_DIR"
fi
if [[ "$TARGET" == "all" || "$TARGET" == "copilot" ]]; then
  mkdir -p "$COPILOT_DIR"
fi

# Load tool mappings
if [[ ! -f "$MAPPINGS_FILE" ]]; then
  echo "Error: $MAPPINGS_FILE not found"
  exit 1
fi

MAPPING_VERSION=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    print(json.load(f)['version'])
" "$MAPPINGS_FILE" 2>/dev/null || echo "unknown")

# Python helper that does the actual generation
generate_all() {
  python3 << 'PYTHON_SCRIPT'
import json
import os
import sys

canonical_dir = os.environ.get("CANONICAL_DIR", "./agents/canonical")
mappings_file = os.environ.get("MAPPINGS_FILE", "./agents/tool-mappings.json")
claude_dir = os.environ.get("CLAUDE_DIR", "./.claude/agents")
copilot_dir = os.environ.get("COPILOT_DIR", "./.github/agents")
mapping_version = os.environ.get("MAPPING_VERSION", "unknown")
check_mode = os.environ.get("CHECK_MODE", "false") == "true"
target = os.environ.get("TARGET", "all")

gen_claude = target in ("all", "claude")
gen_copilot = target in ("all", "copilot")

# Load mappings
with open(mappings_file) as f:
    mappings = json.load(f)

cap_map = mappings["capabilities"]

def parse_frontmatter(content):
    """Parse YAML-like frontmatter from markdown. Simple parser, no PyYAML needed."""
    if not content.startswith("---"):
        return {}, content

    end = content.index("---", 3)
    fm_text = content[3:end].strip()
    body = content[end + 3:].strip()

    fm = {}
    current_key = None
    current_list = None

    for line in fm_text.split("\n"):
        stripped = line.strip()

        if not stripped:
            continue

        # List item
        if stripped.startswith("- ") and current_key:
            if current_list is None:
                current_list = []
                fm[current_key] = current_list
            current_list.append(stripped[2:].strip())
            continue

        # Key-value or key with block scalar
        if ":" in stripped and not stripped.startswith("-"):
            parts = stripped.split(":", 1)
            key = parts[0].strip()
            val = parts[1].strip()

            current_key = key
            current_list = None

            if val in (">-", "|", ">"):
                fm[key] = ""
                continue
            elif val == "[]":
                fm[key] = []
                continue
            elif val.startswith("[") and val.endswith("]"):
                items = val[1:-1].split(",")
                fm[key] = [i.strip().strip("'\"") for i in items if i.strip()]
                continue
            else:
                fm[key] = val.strip("'\"")
                current_list = None
                continue

        # Continuation of block scalar
        if current_key and isinstance(fm.get(current_key), str) and fm[current_key] == "":
            fm[current_key] = stripped
        elif current_key and isinstance(fm.get(current_key), str):
            fm[current_key] += " " + stripped

    return fm, body


def capabilities_to_tools(capabilities, tool):
    """Map canonical capabilities to tool-specific tool names."""
    tools = []
    seen = set()
    for cap in capabilities:
        if cap in cap_map and tool in cap_map[cap]:
            tool_name = cap_map[cap][tool]
            if tool_name not in seen:
                tools.append(tool_name)
                seen.add(tool_name)
    return tools


def generate_claude(name, fm, body):
    """Generate Claude Code agent file."""
    tools = capabilities_to_tools(fm.get("capabilities", []), "claude")
    lines = [
        f"<!-- GENERATED from agents/canonical/{name}.md (mappings v{mapping_version}) — do not edit -->",
        "---",
        f"name: {fm['name']}",
        "description: >-",
        f"  {fm.get('description', '')}",
        "tools:",
    ]
    for t in tools:
        lines.append(f"  - {t}")
    lines.append("---")
    lines.append("")
    lines.append(body)
    return "\n".join(lines) + "\n"


def generate_copilot(name, fm, body):
    """Generate GitHub Copilot agent file."""
    tools = capabilities_to_tools(fm.get("capabilities", []), "copilot")
    delegates = fm.get("delegates_to", [])

    lines = [
        f"<!-- GENERATED from agents/canonical/{name}.md (mappings v{mapping_version}) — do not edit -->",
        "---",
        f"description: \"{fm.get('description', '')}\"",
    ]

    tools_str = ", ".join(tools)
    lines.append(f"tools: [{tools_str}]")

    if delegates:
        lines.append("agents:")
        for d in delegates:
            lines.append(f"  - {d}")

    lines.append("---")
    lines.append("")
    lines.append(body)
    return "\n".join(lines) + "\n"


# Process all canonical agents
stale_files = []
generated_count = 0

for filename in sorted(os.listdir(canonical_dir)):
    if not filename.endswith(".md"):
        continue

    name = filename[:-3]
    filepath = os.path.join(canonical_dir, filename)

    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    fm, body = parse_frontmatter(content)

    if "name" not in fm:
        print(f"  SKIP {filename} — no 'name' in frontmatter")
        continue

    outputs = []
    if gen_claude:
        claude_content = generate_claude(name, fm, body)
        claude_path = os.path.join(claude_dir, f"{name}.md")
        outputs.append((claude_path, claude_content, f".claude/agents/{name}.md"))

    if gen_copilot:
        copilot_content = generate_copilot(name, fm, body)
        copilot_path = os.path.join(copilot_dir, f"{name}.agent.md")
        outputs.append((copilot_path, copilot_content, f".github/agents/{name}.agent.md"))

    if check_mode:
        for path, content_new, label in outputs:
            if not os.path.exists(path):
                stale_files.append(f"  MISSING: {label}")
            else:
                with open(path, encoding="utf-8") as f:
                    existing = f.read()
                if existing != content_new:
                    stale_files.append(f"  STALE: {label}")
    else:
        for path, content_new, label in outputs:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content_new)
            print(f"  {label}")
        generated_count += 1

targets_label = {"all": "Claude Code + GitHub Copilot", "copilot": "GitHub Copilot only", "claude": "Claude Code only"}

if check_mode:
    if stale_files:
        print("Generated agent files are out of date:")
        for s in stale_files:
            print(s)
        print("\nRun 'bash agents/generate.sh' to regenerate.")
        sys.exit(1)
    else:
        print("All generated agent files are up to date.")
        sys.exit(0)
else:
    print(f"\nGenerated {generated_count} agents for {targets_label[target]}.")

PYTHON_SCRIPT
}

echo "Agent Generator (ADR-0004)"
echo "Canonical source: agents/canonical/"
echo "Mappings version: $MAPPING_VERSION"
echo "Target: $TARGET"
echo ""

export REPO_ROOT CANONICAL_DIR MAPPINGS_FILE CLAUDE_DIR COPILOT_DIR MAPPING_VERSION TARGET
export CHECK_MODE=$CHECK_MODE

generate_all
