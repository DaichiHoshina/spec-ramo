# Spec Ramo

[日本語](README.md)

Spec Ramo is a Claude Code plugin for spec-driven development. It splits a spec into Phases, one pull request each, and has the implementer understand each Phase before moving on to the next.

- Name: spec + ramo (Spanish / Italian for "branch"). A spec branches out into one PR per Phase
- Status: v0.2.1
- The skills and generated documents are written in Japanese

## What it does

- Creates a PRD, a Design Doc, an implementation plan, and per-Phase detailed designs from fixed templates, with check scripts
- Splits the implementation plan into one Phase = one PR, and checks that each PR's estimated diff stays under a limit (400 lines by default)
- `/specramo:explain` explains the design before implementation and the code after it, and ends with one question to check your understanding
- `/specramo:review` reviews the diff in parallel with separate agents per perspective: comparison with the design documents, past review findings, the repo's rules, and language guidelines
- Each Phase's state (not started / in progress / reviewed / PR created) is recorded in a table in the plan, and `/specramo:status` lists it

## Install

Run these two in a Claude Code session:

```text
/plugin marketplace add DaichiHoshina/spec-ramo
/plugin install specramo@specramo
```

In a session, `/plugin install` opens the plugin's detail panel; choose a scope (user / project) there. From a shell, `claude plugin install specramo@specramo` installs it directly.

Then run `/specramo:init` in the repo where you want to use it. It creates the config file (`.specramo/config.yml`) and the output directory (`.specramo/specs/`). Existing files are left untouched.

### Installing from a private repo

Claude Code has no git token of its own; it clones with the git credentials on your machine. While this repo is private, set up one of these before `/plugin marketplace add`:

- An SSH key registered on GitHub that works without a passphrase prompt, with `github.com` already in `known_hosts`
- `gh auth login` followed by `gh auth setup-git`, so git uses the GitHub CLI credentials

Setting `GITHUB_TOKEN` in the environment alone does not authenticate.

### Updating

Marketplaces you add yourself do not auto-update by default. To update:

1. `/plugin marketplace update specramo` to refresh the listing
2. In `/plugin`, open Spec Ramo on the Installed tab and press Update now (from a shell: `claude plugin update specramo@specramo`)
3. `/reload-plugins` to apply it to the running session

To enable auto-update, open specramo on the Marketplaces tab in `/plugin` and press Enable auto-update.

## Commands

Go from PRD to PR in this order:

| Step | Command | What it does |
|---|---|---|
| 1 | `/specramo:init` | Create the config file and output directory |
| 2 | `/specramo:prd` | Gather requirements interactively and write a PRD |
| 3 | `/specramo:design` | Write a Design Doc that fixes behavior in an acceptance-criteria table |
| 4 | `/specramo:plan` | Split the Design Doc into an implementation plan, one Phase = one PR |
| 5 | `/specramo:phase-design` | Decide how to implement one Phase after reading the existing code (skipped for Phases with no open decisions) |
| 6 | `/specramo:explain` | Explain the Phase's design before implementation |
| 7 | `/specramo:implement` | Implement one Phase and verify its completion criteria with commands |
| 8 | `/specramo:review` | Review the Phase's diff from 4 perspectives in parallel |
| 9 | `/specramo:explain` | Explain the code in the diff; once you understand it, you open the PR |
| - | `/specramo:status` | Show each feature's Phase progress and the command to run next |

Repeat steps 5 to 9 for each Phase. You open the PRs yourself; Spec Ramo never opens a PR.

## When not to use it

Spec Ramo targets work large enough to need two or more PRs. For a typo or a small single-file fix, implement it directly without starting from a PRD.

## Configuration

Keys in `.specramo/config.yml`:

| Key | Default | Meaning |
|---|---|---|
| `specs_dir` | `.specramo/specs` | Output directory; one sub-directory per feature |
| `max_lines` | `400` | Upper limit of estimated changed lines per PR (excluding tests) |
| `test_paths` | none | Path patterns of test files excluded from the line count |
| `branch_pattern` | none | Shape of Phase branch names (e.g. `phase/<PR>-<slug>`). When empty, only the presence of a name is checked |
| `rules` | none | Rule files that review agent C reads. When empty, the files in `.claude/rules/` are used |

The environment variable `SPECRAMO_REVIEW_DATA_DIR` points review agent B at your team's review-finding data (default `~/.config/specramo/review-data/`). This data is built from your team's past reviews and contains internal information, so keep it out of the repo. If the directory has no files, agent B is not started.

To use your own templates, put a file with the same name at `.specramo/templates/<prd|design|plan|phase-design>.md`.

## Example

[examples/overdue-todos](examples/overdue-todos/) holds the documents from PRD to a Phase detailed design, for a feature that adds a list of overdue TODOs to a small TODO API.

## Development

```bash
bats tests/                          # tests for scripts and skills
bash scripts/check-ai-tools-refs.sh  # no paths that exist only on the author's machine
claude plugin validate .             # validate the plugin definition
```

Bump `version` in `.claude-plugin/plugin.json` for each release. If the version stays the same, users do not receive new commits when they update.

## License

[MIT](LICENSE)
