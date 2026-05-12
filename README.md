# spell

[![Spell Check](https://github.com/vladdoster/spell-/actions/workflows/spell-check.yml/badge.svg)](https://github.com/vladdoster/spell-/actions/workflows/spell-check.yml)

A standalone CLI tool for spell checking repositories using codespell.

## Features

- 🔍 Automatically finds and fixes spelling errors in markdown and text files
- 🎯 Customizable ignore words and file skipping
- 🍴 Automatically forks repositories and creates pull requests
- 🧹 Optional fork cleanup after completion
- 🎨 Color-coded output for better user experience
- ✅ Uses zparseopts for robust argument parsing

## Requirements

- `zsh` - Z shell
- `gh` - GitHub CLI (authenticated)
- `uv` - Python package manager
- `git` - Version control system
- `GH_TOKEN` - GitHub personal access token (set as environment variable)

## Installation

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/vladdoster/spell-/main/spell-check
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
- `-d, --delete-fork` - Delete fork after completion
- `-h, --help` - Show help message

### Examples

Basic spell check:
```bash
spell-check -r owner/repo
```

Ignore specific words:
```bash
spell-check -r owner/repo -i "myword anotherword"
```

Skip specific files and delete fork after:
```bash
spell-check -r owner/repo -s "*.log,*.tmp" -d
```

## How It Works

1. **Validates inputs** - Checks for required commands and validates repository
2. **Clones repository** - Creates a local clone of the target repository
3. **Runs codespell** - Scans markdown and text files for spelling errors
4. **Checks for changes** - Determines if any corrections were made
5. **Creates fork** - Forks the repository (if changes found)
6. **Commits & pushes** - Creates a branch with fixes and pushes to fork
7. **Cleanup** - Optionally deletes the fork after completion

## Environment Variables

- `GH_TOKEN` - GitHub personal access token (required)
- `GITHUB_REPOSITORY_OWNER` - GitHub username (optional, detected automatically)

## License

MIT
