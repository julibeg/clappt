# clappt

Minimal Apptainer setup for running Claude Code with masked host username and paths.
Provides hooks for scrubbing secrets (email addresses, API keys, etc.) from tool call outputs and running Ruff on Python files, along with testing support for the hooks.
You need to provide a scrubber executable (`scrub`) on `PATH` when running `clappt` for the scrubbing hooks to work.
Ideally this executable is a binary so that the agent can't read the source and glean the secrets.
A simple way to create a binary from a shell script is to use [shc](https://github.com/neurobin/shc).
`shc` is available inside the container.

**IMPORTANT**: This does not provide actual security (especially against prompt injection attacks or similar).
If a coding agent has tool-calling permissions and really wants to gain sensitive information, it can.
This Apptainer image & wrapper script (alongside the Claude Code hooks) just try to marginally improve privacy by filtering what is sent to the LLM.

## The wrapper and container

The wrapper masks the host user name and paths inside the container.
It overlays `/etc/passwd` and `/etc/group` to replace the host username with `user` and binds the current working directory to a masked path under `/work`.
Overlaying `/etc/passwd` and `/etc/group` is hacky, but provides obfuscation without breaking things in most cases.

If the host has `micromamba` installed (`MAMBA_ROOT_PREFIX` is set, the directory it points to exists, and the `micromamba` command is available), the wrapper sets up the container so that:

- you / the agent can use any conda env with `micromamba run -n <env-name> ...` inside the container
- the binaries installed in the currently active conda/mamba env are available
- the binaries installed in an env called `cli-utils` (if it exists) are available

If the host has Rust installed (i.e. `~/.cargo` and `~/.rustup` exist), it is also made available inside the container.

## Claude Code hooks

`clappt` comes with a small set of hooks for scrubbing tool call output before it reaches the agent as well as running ruff on edited Python files.

### Hooks setup

Use the helper script to install the hooks in `~/.claude/settings.json` and symlink the hooks directory into `~/.claude`:

```bash
./hooks/add-hooks-to-settings-and-symlink.sh
```

### Hooks testing

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

#### Results

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
