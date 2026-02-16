# Hooks test details

- `scrub` is an `shc`-compiled binary built from `scrub.sh`.
- The scrubber replaces `hello` with `hi`.
- `test-files/test-1.txt` contains `hi` and `test-files/test-2.txt` contains `hello`.
- When the hooks work, the agent only sees `hi` from both files.
