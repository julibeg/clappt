# clappt

Minimal Apptainer setup for running Claude Code with masked host username and paths.
Provides hooks for scrubbing secrets (email addresses, API keys, etc.) from tool call outputs and running Ruff on Python files, along with testing support for the hooks.
You need to provide a scrubber executable (`scrub`) on `PATH` when running `clappt` for the scrubbing hooks to work.
Ideally this executable is a binary so that the agent can't read the source and glean the secrets.
A simple way to create a binary from a shell script is to use [shc](https://github.com/neurobin/shc).

**IMPORTANT**: This does not intend to be actual security (especially against prompt injection attacks or similar).
It just tries to pick the low-hanging fruit in terms of sending less sensitive info to the LLM.

## What it provides

- An Apptainer container that masks host user name and paths for Claude Code usage (it overlays `/etc/passwd` and `/etc/group` to replace the host username with `user` and binds the current working directory to a masked path under `/work` in the container). Overlaying `/etc/passwd` and `/etc/group` is hacky, but provides enough obfuscation without breaking things (in most cases).
- Hooks for:
  - Scrubbing secrets from `Read` and `Bash` tool call outputs before they reach the LLM (requires a `scrub` executable on `PATH` when running the wrapper script).
  - Running Ruff on Python files.
- Testing support to verify hooks work correctly.

## Hooks setup

Use the helper script to install the hooks in your Claude settings and symlink the hooks directory into `~/.claude`:

```bash
./hooks/add-hooks-to-settings-and-symlink.sh
```

This updates `~/.claude/settings.json` and ensures `~/.claude/hooks` points at the repo hooks directory.

## Hooks testing

Run the built-in test mode:

```bash
./clappt --test-hooks
```

Expected behavior:
- Reading `test-1.txt` and `test-2.txt` via the `Read` tool should return the same content (scrubbed output).
- The same applies for reading the files with `cat` (`Bash` tool).
- Editing `test.py` should trigger a Ruff warning about the unused variable.

Example output of Claude Code for the hooks test:

```md
Perfect! Here are the results of the hooks setup tests:

## Results

1. **Read tool vs Read tool on .txt files:**
   - `test-1.txt` via Read: Shows full content with line numbers ("hi 1", "hi 2", "hi 3", blank line)
   - `test-2.txt` via Read: **Sanitized by hook** - shows only the content without line numbers ("hi 1", "hi 2", "hi 3")
   - ✅ Different content! The hook successfully sanitized one file.

2. **Cat command on .txt files:**
   - Both files show identical content: "hi 1", "hi 2", "hi 3"
   - ✅ Same content when using `cat` (bypasses the Read tool hook)

3. **Edit tool on Python file:**
   - ✅ **Yes, you get a linter error!**
   - **Error: `F841 Local variable 'unused_var' is assigned to but never used`**
   - The hook detected that the variable `unused_var` on line 2 is never used and reported it as a linting issue.

The hooks are working correctly! The Read hook sanitizes sensitive content in certain files, and the Edit hook runs a linter (ruff) to catch code quality issues.
```
