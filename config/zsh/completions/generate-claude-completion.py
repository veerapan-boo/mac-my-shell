#!/usr/bin/env python3
"""
Generates ~/.zsh/completions/_claude by parsing `claude --help` (and the
--help of subcommands that take their own [options]) at run time.

Re-run this after upgrading Claude Code so newly added/renamed/removed
flags show up in Tab-completion. Safe to re-run any time: it always
regenerates the whole file from scratch.
"""
import re
import subprocess
import sys
from pathlib import Path

OUT_PATH = Path.home() / ".zsh" / "completions" / "_claude"

# Subcommands whose own --help is worth parsing for their own [options].
# (Matches the ones the top-level `Commands:` list marks with "[options]".)
OPTION_SUBCOMMANDS = ["agents", "gateway", "import", "install", "ultrareview"]


def run_help(*args):
    result = subprocess.run(
        ["claude", *args, "--help"], capture_output=True, text=True, timeout=15
    )
    return result.stdout


def esc(text):
    """Escape a string for safe embedding inside a single-quoted _arguments
    spec, where ']' closes the description and ':' separates fields."""
    text = text.replace("\\", "\\\\")
    text = text.replace("]", "\\]")
    text = text.replace(":", "\\:")
    text = text.replace("'", "'\\''")
    return text


def esc_plain(text):
    """Escape a string for a plain single-quoted 'name:description' entry
    (e.g. _describe arrays), where only ':' is a field separator -- no
    bracket escaping, since _describe doesn't parse [...] specially."""
    text = text.replace("\\", "\\\\")
    text = text.replace(":", "\\:")
    text = text.replace("'", "'\\''")
    return text


ENTRY_START_RE = re.compile(r"^  (\S)")
SPLIT_RE = re.compile(r"^(\S.*?\S|\S)  +(\S.*)$")


def parse_block(lines):
    """Group an indented help block into (header, description) entries.

    A new entry starts at a line with exactly two leading spaces followed
    by a non-space character; anything more deeply indented is a
    continuation (wrapped description) of the entry above it.
    """
    entries = []
    current = None
    for raw in lines:
        if not raw.strip():
            continue
        if ENTRY_START_RE.match(raw):
            if current is not None:
                entries.append(current)
            current = [raw.strip()]
        elif current is not None:
            current.append(raw.strip())
    if current is not None:
        entries.append(current)

    parsed = []
    for entry_lines in entries:
        header = entry_lines[0]
        rest = entry_lines[1:]
        m = SPLIT_RE.match(header)
        if m:
            head_part, desc_first = m.group(1), m.group(2)
        else:
            head_part, desc_first = header, None
        desc_parts = ([desc_first] if desc_first else []) + rest
        description = " ".join(desc_parts).strip()
        parsed.append((head_part, description))
    return parsed


CHOICES_RE = re.compile(r"choices:\s*((?:\"[^\"]+\"(?:,\s*)?)+)")
QUOTED_RE = re.compile(r'"([^"]+)"')

FILE_ACTION_FLAGS = {
    "--add-dir",
    "--debug-file",
    "--mcp-config",
    "--plugin-dir",
    "--settings",
    "--file",
}


def parse_option_head(head_part):
    """Split an option header like '-c, --continue' or
    '--allowedTools, --allowed-tools <tools...>' into (flags, argspec)."""
    m = re.search(r"([<\[])([^<>\[\]]*)([>\]])$", head_part)
    if m:
        open_ch, inner, _close_ch = m.groups()
        flags_part = head_part[: m.start()].strip()
        required = open_ch == "<"
        variadic = inner.endswith("...")
        placeholder = inner[:-3] if variadic else inner
        pipe_choices = placeholder.split("|") if (required and "|" in placeholder) else None
        argspec = {
            "required": required,
            "variadic": variadic,
            "placeholder": placeholder,
            "pipe_choices": pipe_choices,
        }
    else:
        flags_part = head_part.strip()
        argspec = None

    flags = [f.strip() for f in flags_part.split(",") if f.strip()]
    return flags, argspec


def build_arg_spec(flag, description, argspec):
    desc = esc(description)
    if argspec is None:
        return f"'{flag}[{desc}]'"

    choices = None
    cm = CHOICES_RE.search(description)
    if cm:
        choices = QUOTED_RE.findall(cm.group(1))
    elif argspec["pipe_choices"]:
        choices = argspec["pipe_choices"]

    if choices:
        action = "(" + " ".join(choices) + ")"
    elif flag in FILE_ACTION_FLAGS:
        action = "_files"
    else:
        action = ""

    colon = ":" if argspec["required"] else "::"
    star = "*" if argspec["variadic"] else ""
    placeholder = esc(argspec["placeholder"] or "value")
    return f"'{star}{flag}[{desc}]{colon}{placeholder}:{action}'"


def build_option_specs(option_entries):
    specs = []
    for head_part, description in option_entries:
        flags, argspec = parse_option_head(head_part)
        for flag in flags:
            specs.append(build_arg_spec(flag, description, argspec))
    return specs


def indent(lines, n=4):
    pad = " " * n
    return [pad + l for l in lines]


def main():
    top_help = run_help()
    lines = top_help.splitlines()

    def section(name, stop_names):
        try:
            start = next(i for i, l in enumerate(lines) if l.strip() == f"{name}:")
        except StopIteration:
            return []
        block = []
        for l in lines[start + 1 :]:
            if l.strip() and not l.startswith(" ") :
                break
            if any(l.strip() == f"{s}:" for s in stop_names):
                break
            block.append(l)
        return block

    options_block = section("Options", ["Commands", "Arguments", "Examples"])
    commands_block = section("Commands", ["Options", "Arguments", "Examples"])

    top_option_entries = parse_block(options_block)
    top_command_entries = parse_block(commands_block)

    top_option_specs = build_option_specs(top_option_entries)

    subcommand_list = []
    subcommand_names = []
    for head_part, description in top_command_entries:
        name_part = re.sub(r"\s*\[[^\]]*\]", "", head_part).strip()
        for alias in name_part.split("|"):
            subcommand_names.append(alias)
        subcommand_list.append((name_part, description))

    # Fetch nested options for subcommands that take their own [options].
    nested_specs_by_name = {}
    for sub in OPTION_SUBCOMMANDS:
        try:
            sub_help = run_help(sub)
        except Exception as e:  # pragma: no cover - best-effort
            print(f"warning: couldn't fetch help for '{sub}': {e}", file=sys.stderr)
            continue
        sub_lines = sub_help.splitlines()
        try:
            start = next(i for i, l in enumerate(sub_lines) if l.strip() == "Options:")
        except StopIteration:
            continue
        block = []
        for l in sub_lines[start + 1 :]:
            if l.strip() and not l.startswith(" "):
                break
            block.append(l)
        entries = parse_block(block)
        nested_specs_by_name[sub] = build_option_specs(entries)

    out = []
    out.append("#compdef claude")
    out.append("")
    out.append("# Auto-generated by generate-claude-completion.py -- do not hand-edit.")
    out.append("# Re-run that script after a Claude Code upgrade to refresh flags/commands.")
    out.append("")
    out.append("_claude() {")
    out.append("  local -a top_opts subcommands")
    out.append("")
    out.append("  top_opts=(")
    out.extend(indent(top_option_specs, 4))
    out.append("  )")
    out.append("")
    out.append("  subcommands=(")
    for name_part, description in subcommand_list:
        out.append(f"    '{esc_plain(name_part)}:{esc_plain(description)}'")
    out.append("  )")
    out.append("")
    out.append("  _arguments -C \\")
    out.append("    $top_opts \\")
    out.append("    '1: :->cmd_or_prompt' \\")
    out.append("    '*::arg:->rest'")
    out.append("")
    out.append("  case $state in")
    out.append("    cmd_or_prompt)")
    out.append("      _describe -t commands 'claude command' subcommands")
    out.append("      ;;")
    out.append("    rest)")
    out.append("      case $words[1] in")
    for sub, specs in nested_specs_by_name.items():
        out.append(f"        {sub})")
        if specs:
            out.append("          _arguments \\")
            for i, spec in enumerate(specs):
                sep = " \\" if i < len(specs) - 1 else ""
                out.append(f"            {spec}{sep}")
        else:
            out.append("          _files")
        out.append("          ;;")
    out.append("        *)")
    out.append("          _files")
    out.append("          ;;")
    out.append("      esac")
    out.append("      ;;")
    out.append("  esac")
    out.append("}")
    out.append("")
    out.append("_claude \"$@\"")
    out.append("")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text("\n".join(out))
    print(f"wrote {OUT_PATH} ({len(top_option_specs)} top-level flags, "
          f"{len(subcommand_list)} subcommands, "
          f"{sum(len(v) for v in nested_specs_by_name.values())} nested flags)")


if __name__ == "__main__":
    main()
