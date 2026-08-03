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
  environment with Python, Ruff, fd, ripgrep, pandas, NumPy, Matplotlib,
  Seaborn, SciPy, and scikit-learn
- Firecrawl CLI
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
./pipod/pipod --gpu
```

Use `--gpu` to expose NVIDIA devices and host driver libraries without requiring
NVIDIA Container Toolkit. This is a manual fallback for older Podman versions;
prefer CDI when it becomes available on the host.

Use `--stage-dirs /path/one,/path/two:ro` to mount several absolute paths. Each
is masked as `/work/<hash>/<basename>`; `:ro` makes one path read-only. Linked
Git worktrees are handled automatically. Pixi projects use `.pixi-containers` for
a container-specific environment instead of reusing the host `.pixi` directory.

The wrapper mounts agent state from `~/.claude`, `~/.codex`, and `~/.pi`. A
top-level relative symlink in `~/.claude`, `~/.codex`, or `~/.pi/agent` gets its
resolved target mounted at the corresponding relative container path. This also
keeps existing Claude hooks working. Absolute symlinks work but expose their
target path and produce a warning. Firecrawl's `~/.config/firecrawl-cli` and
`~/.cache` are writable; `~/.gitconfig` is read-only. The rest of host
`~/.config` is not mounted.

Rootless Podman's `keep-id` user namespace maps the host user to the image's
neutral `user` account, keeping bind-mounted files writable. SELinux labeling
is disabled so pipod does not relabel agent configuration or project paths.

## pnpm and host installs

Build-time pnpm installs do not use the host pnpm store or global packages. At
runtime, the wrapper mounts the host store when present so packages linked from
the mounted `~/.pi` state keep working; host global packages remain isolated. A
different host pnpm version is normally harmless. npm is used only to bootstrap
pnpm; pnpm installs Pi, Firecrawl, and Playwright with
`--ignore-scripts`. Each image build installs the latest Claude and Codex
releases and refreshes Pi to the newest release allowed by pnpm's 2,880-minute
(48-hour) minimum release age. Runtime pnpm commands enforce the same release
age through an environment override, independent of host pnpm configuration.

Do not reuse host-created `node_modules` when host and container Node versions or
platform libraries differ. Native addons and generated executable shims can be
incompatible. Install dependencies inside the environment where they will run;
the lockfile itself is safe to share.
