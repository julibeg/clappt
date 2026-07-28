# clappt

Minimal Apptainer setup for running Claude Code with masked host username and paths.
Provides a hook that runs Ruff on edited Python files, along with testing support.

**IMPORTANT**: This does not provide actual security (especially against prompt injection attacks or similar).
If a coding agent has tool-calling permissions and really wants to gain sensitive information, it can.
This Apptainer image & wrapper script just try to marginally improve privacy by masking host paths and usernames.

## The wrapper and container

The wrapper masks the host user name and paths inside the container.
It overlays `/etc/passwd` and `/etc/group` to replace the host username with `user` and binds the current working directory to a masked path under `/work`.
Use `--stage-dirs /path/one,/path/two:ro` to bind absolute paths instead; a `:ro` suffix makes an individual directory read-only. Each gets its own `/work/<hash>/<name>` path and the container starts in `/work`.
Use `--gpu` to expose NVIDIA GPUs and host driver libraries via Apptainer's
`--nv` support.
Overlaying `/etc/passwd` and `/etc/group` is hacky, but provides obfuscation without breaking things in most cases.

If the host has `micromamba` installed (`MAMBA_ROOT_PREFIX` is set, the directory it points to exists, and the `micromamba` command is available), the wrapper sets up the container so that:

- you / the agent can use any conda env with `micromamba run -n <env-name> ...` inside the container
- the binaries installed in the currently active conda/mamba env are available
- the binaries installed in an env called `cli-utils` (if it exists) are available

If the host has Rust installed (i.e. `~/.cargo` and `~/.rustup` exist), it is also made available inside the container.

## Claude Code hooks

`clappt` comes with a hook that runs Ruff on edited Python files.

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

Expected behavior: editing `test.py` triggers a Ruff warning about the unused variable.
