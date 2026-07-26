# pipod

Podman image and wrapper for running Claude Code, Codex, and Pi with masked host
usernames and project paths. It lives alongside the existing Apptainer-based
`clappt`; it does not replace or modify that setup.

This is privacy obfuscation, not a security boundary. An agent with mounted
credentials and write access can still disclose or alter them.

## Image

The image is based on Microsoft's Ubuntu Noble Playwright image and includes:

- Chromium, Firefox, WebKit, and the Playwright CLI
- Claude Code and Codex from their native installers; Pi from pnpm with
  lifecycle scripts disabled
- pnpm, Pixi, stable Rust, ShellCheck, and a Pixi-managed `cli-utils`
  environment with Python, Ruff, fd, and ripgrep
- Firecrawl CLI and Nextflow
- Git, build tools, jq, Vim, PDF tools, and ImageMagick

From the repository root:

```bash
./pipod/build.sh
./pipod/test.sh
```

Output is also saved to `pipod/build.log` and `pipod/test.log`.

Set `IMAGE` to use another tag. The default is the local-only tag
`localhost/pipod:latest`; Podman will not confuse it with Docker Hub.

## Wrapper

```bash
./pipod/pipod
./pipod/pipod -- pi
./pipod/pipod -- claude
./pipod/pipod -- codex
```

Use `--stage-dirs /path/one,/path/two:ro` to mount several absolute paths. Each
is masked as `/work/<hash>/<basename>`; `:ro` makes one path read-only. Linked
Git worktrees are handled automatically. Pixi projects use `.pixi-pipod` for a
container-specific environment instead of reusing the host `.pixi` directory.

The wrapper mounts agent state from `~/.claude`, `~/.codex`, and `~/.pi`. A
top-level relative symlink in `~/.claude`, `~/.codex`, or `~/.pi/agent` gets its
resolved target mounted at the corresponding relative container path. This also
keeps existing Claude hooks working. Absolute symlinks work but expose their
target path and produce a warning.

Rootless Podman's `keep-id` user namespace maps the host user to the image's
neutral `user` account, keeping bind-mounted files writable. SELinux labeling
is disabled so pipod does not relabel agent configuration or project paths.

## pnpm and host installs

The image's pinned pnpm does not use the host pnpm store or global packages, so
a different host pnpm version is normally harmless. npm is used only to
bootstrap pnpm; pnpm installs Pi, Firecrawl, and Playwright with
`--ignore-scripts`. npm's bootstrap uses the same restriction. The Claude and
Codex native
installers receive exact versions. Keep those pins at least 48 hours old when
updating them. Image builds and runtime pnpm commands enforce a 2,880-minute
(48-hour) minimum release age.

Do not reuse host-created `node_modules` when host and container Node versions or
platform libraries differ. Native addons and generated executable shims can be
incompatible. Install dependencies inside the environment where they will run;
the lockfile itself is safe to share.
