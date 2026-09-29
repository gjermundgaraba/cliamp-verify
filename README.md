# cliamp-verify

The `verify-cliamp` agent skill: drive a real, isolated [cliamp](https://github.com/bjarneo/cliamp) instance (TUI or daemon) through keys, CLI and IPC, and capture evidence. [`SKILL.md`](SKILL.md) is the entry point.

Kept outside the cliamp repo. `vc up` builds whichever cliamp checkout it runs in, so one install serves every worktree.

## Install

Link this directory in as a user-level skill:

```sh
ln -s ~/ws/pers/cliamp-verify ~/.agents/skills/verify-cliamp
ln -s ~/ws/pers/cliamp-verify ~/.claude/skills/verify-cliamp
```

## Layout

- `scripts/vc`: the run helper (build, launch, drive, observe, tear down)
- `scripts/servers/`, `scripts/make-library`: disposable media servers on a generated fixture library
- `features/`: per-feature verification recipes
- `agents/openai.yaml`: Codex metadata (user-invocable only, like `disable-model-invocation` in `SKILL.md`)
- `clankerbox.md`, `clankerbox-profile/`, `scripts/clankerbox-docker`: Linux runs in a clankerbox microVM
