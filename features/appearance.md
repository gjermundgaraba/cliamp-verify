# Themes and visualizers

A user changes how cliamp looks: picking a color theme from a filterable picker with live preview, cycling or picking a visualizer, opening the full-screen visualizer, or doing the same from `cliamp theme` and `cliamp vis`. Both choices come back on the next launch.

## Sub-features

- `look-theme-picker` opens the theme picker with `t`. Moving the cursor previews, `Enter` applies and `Esc` restores the previous theme.
- `look-theme-filter` filters the theme list with `/`.
- `look-theme-cli` sets a theme with `cliamp theme <name>` and lists themes with `cliamp theme list`.
- `look-vis-cycle` cycles visualizers with `v`.
- `look-vis-picker` picks a visualizer from a list with `Ctrl+V`.
- `look-vis-full` opens the full-screen visualizer with `V`.
- `look-vis-cli` sets a visualizer with `cliamp vis <name|next|list>`.
- `look-persist` saves `theme` and `visualizer` to `config.toml`.

## How to get to it (user POV)

- Playlist view (`[Playlist]`): `t` for themes, `v` to cycle visualizers, `Ctrl+V` for the visualizer picker, `V` for full screen.
- Inside a picker: `Up`/`Down` preview, `/` filter, `Enter` apply (or complete the filter), `Esc` restore.
- Terminal: `cliamp theme <name|list>` and `cliamp vis <name|next|list>`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`. The theme is `Default - Terminal colors` and the visualizer is `Bars`.

- **Open theme picker.** Press `t`. Run `$VC keys $RUN t` then `$VC wait-screen $RUN '\[Themes\]'`. The list header reads `── Themes  1/23` with `> Default - Terminal colors`.
- **Preview.** Move down one row. Run `$VC keys $RUN Down`. `.theme.name` is the highlighted row's name (for example `alucard`), even though nothing has been confirmed.
- **Cancel restores.** Press `Esc`. Run `$VC keys $RUN Escape` then `$VC wait-screen $RUN '\[Playlist\]'`. `.theme.name` is back to `Default - Terminal colors`.
- **Filter and apply.** Run `$VC keys $RUN t`, `$VC keys $RUN /`, `$VC type $RUN nord`, then `$VC wait-screen $RUN '/ nord'`. Then press `Enter` twice (complete the filter, then apply): `$VC keys $RUN Enter Enter`. The header returns to `[Playlist]` and `.theme.name` is `nord`.
- **Theme from CLI.** Run `$VC cli $RUN --save look/theme -- theme dracula`. Stdout `Theme: dracula`, and `.theme` has `"accent":"#bd93f9"`. Run `$VC cli $RUN -- theme nosuchtheme`. Exit `1` with `job failed (not_found): resource not found`, and `.theme.name` is still `dracula`.
- **Cycle visualizer.** Press `v`. Run `$VC keys $RUN v` then `$VC wait-state $RUN '.visualizer == "BarsDot"'`.
- **Visualizer picker.** Press `Ctrl+V`. Run `$VC keys $RUN C-v` then `$VC wait-screen $RUN '\[Visualizers\]'`. The list header reads `── Visualizers  2/33` with `> BarsDot`. Close it with `$VC keys $RUN Escape`.
- **Full screen.** Press `V`. Run `$VC keys $RUN V`, then check that `$VC screen $RUN` no longer contains `C L I A M P`. Only the track, the time and the visualizer remain. Press `v` inside (`$VC keys $RUN v`) and `.visualizer` becomes `Rain`. Leave with `$VC keys $RUN Escape`, and the header `[Playlist]` returns.
- **Visualizer from CLI.** Run `$VC cli $RUN --save look/vis -- vis next`. Stdout `Visualizer: BarsOutline`. `cliamp vis list` marks the active one with `*`. `cliamp vis nosuchvis` exits `1` with `not_found`.
- **Persisted and relaunched.** Run `$VC files $RUN config.toml`. It has `theme = "dracula"` and `visualizer = "BarsOutline"`. Run `$VC restart $RUN`, then `$VC wait-state $RUN '.theme.name == "dracula" and .visualizer == "BarsOutline"'`.
- **Proof.** Run `$VC screen $RUN look/final` and `$VC save $RUN config.toml look/config.toml`.

## Gotchas

- `t` and `v` do nothing in the provider pane. Check for `[Playlist]` first: a stray `Esc` from the playlist opens the provider pane.
- Previewing changes `.theme` in the snapshot before `Enter`. A snapshot alone doesn't prove a theme was applied, so check that the picker closed too.
- In the theme picker with a filter active, the first `Enter` completes the filter and the second applies. With no filter, one `Enter` applies.
- `cliamp theme list` doesn't print `Default - Terminal colors`, but the picker lists it first.
- `theme` and `vis` fail with `unknown_operation` against a daemon (`--daemon`).
