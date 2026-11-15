# spell-check

[![Spell Check](https://github.com/vladdoster/spell-check/actions/workflows/spell-check.yml/badge.svg)](https://github.com/vladdoster/spell-check/actions/workflows/spell-check.yml)

A standalone CLI tool for spell checking repositories using codespell.

Point it at a repository owned by another account. It pushes the fixes to a branch on your fork.
You open the pull request from that branch. Options let you ignore words, skip files, preview the fixes, or delete the fork.

## GitHub action

CI runs the spell-fix pipeline as a **Docker container action** (`action.yml` + `Dockerfile` +
`entrypoint.sh`). Trigger it via **workflow_dispatch** on the
[Spell Check workflow](.github/workflows/spell-check.yml): it codespells the target repository,
and when it finds fixes it forks the repo and pushes them to a `docs/fix-spelling` branch for you
to open a pull request. A second, approval-gated `Delete fork` job cleans up the fork.

`Dockerfile.base` defines the toolchain (Python, git, gh, codespell). The
[Base Image workflow](.github/workflows/base-image.yml) publishes it to `ghcr.io/vladdoster/spell-check-base`
on every change and once a week. The action's `Dockerfile` adds only `entrypoint.sh`, so runs skip the toolchain build.

### Action inputs

| Input          | Required | Description                                                      |
| -------------- | -------- | ---------------------------------------------------------------- |
| `repository`   | yes      | Repository slug (`user/repo`) to spell-check.                    |
| `ignore`       | no       | Space-separated words to ignore.                                 |
| `skip`         | no       | Comma-separated files/globs to skip.                             |
| `github-token` | yes      | PAT with fork/push/delete permissions.                           |
| `delete-fork`  | no       | When `true`, delete the fork named by `repository`.              |
| `dry-run`      | no       | When `true`, stop after reporting fixes; never fork, push, or delete. |

The workflow supplies the token from the `GH_PAT` repository secret.

## Standalone CLI

The `spell-check` zsh script runs the same steps locally. It checks only `.md`, `.mdx`, and `.txt` files, with the latest codespell.
The action checks every file except dotfiles, with codespell 2.4.2. Results can differ between them on the same repository.

## Requirements

- `zsh` - Z shell
- `gh` - GitHub CLI (authenticated)
- `uv` - Python package manager. The script runs codespell with `uvx`.
- `git` - Version control system
- `jq` - JSON processor

## Installation

1. Download the script:

   ```bash
   curl -O https://raw.githubusercontent.com/vladdoster/spell-check/main/spell-check
   chmod +x spell-check
   ```

2. Move to your PATH (optional):
   ```bash
   sudo mv spell-check /usr/local/bin/
   ```

## Usage

```bash
spell-check [OPTIONS]
```

### Options

- `-r, --repository REPO` - Repository slug (user/repo) [required]
- `-i, --ignore WORDS` - Space-separated list of words to ignore
- `-s, --skip FILES` - Comma-separated list of files to skip
- `-n, --dry-run` - Stop after the report; never fork, push, or delete
- `--include-release-docs` - Also check release and legal docs (`CHANGELOG*`, `LICENSE`, `COPYING`, `HISTORY`, `NEWS`, and changelog, changeset, or release dirs). They are skipped by default.
- `-d, --delete-fork` - Delete the fork right after the push. This also deletes the fix branch, so you cannot open a pull request from it.
- `-h, --help` - Show help message

### Examples

Preview the fixes without forking or pushing:

```bash
spell-check -r owner/repo -n
```

Check the report for wrong fixes, such as `AKS` changed to `ASK`.
Add those words with `-i`, then run again without `-n`.

Fix and push:

```bash
spell-check -r owner/repo
```

Ignore specific words:

```bash
spell-check -r owner/repo -i "myword anotherword"
```

Skip specific files:

```bash
spell-check -r owner/repo -s "*.log,*.tmp"
```

## How it works

1. Clones the target repository into a temporary directory, not your working directory.
2. Forks the repository only when codespell changed files.
3. Force-pushes the fixes to `docs/fix-spelling` on your fork. This replaces the branch from any earlier run.

## Environment variables

- `GH_TOKEN` - GitHub personal access token. You can skip it when `gh` is logged in. The script then uses `gh auth token`.
- `GITHUB_REPOSITORY_OWNER` - GitHub username (optional, detected automatically)

## License

MIT
