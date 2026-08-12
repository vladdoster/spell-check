#!/bin/sh
# entrypoint.sh — Docker container action: codespell a target repo and push fixes to a fork.
# POSIX sh. Preserves the behavior of the former inline spell-check workflow.
set -eux

# Problem matchers run on the VM, outside this container, so the matcher config must
# live in the bind-mounted workspace. Copy it there and register it by its relative
# path — the container's absolute path is not the same as the VM's. Outside Actions
# (local `docker run`) there is no workspace and matchers do nothing, so skip it.
if [ -n "${GITHUB_WORKSPACE:-}" ]; then
  cp /codespell-problem-matcher.json "${GITHUB_WORKSPACE}/"
  echo "::add-matcher::codespell-problem-matcher.json"
fi

# --- inputs -----------------------------------------------------------------
repository="${1:-${INPUT_REPOSITORY:-}}"
ignore="${2:-${INPUT_IGNORE:-}}"
skip="${3:-${INPUT_SKIP:-}}"
: "${GH_TOKEN:?GH_TOKEN is required}"

# Append to the job step summary / outputs only when running under Actions.
step_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%b' "$1" >>"${GITHUB_STEP_SUMMARY}" || true
}
set_output() {
  [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT}" || true
}

# GitHub logins and repo names are case-insensitive; normalize before comparing slugs.
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Release/legal docs, matched case-insensitively: names come bare, .txt, or .md;
# dirs match all files inside them. Shared by find_release_docs/list_spell_targets.
# changelog* is a find pattern (loops run under set -f), so CHANGELOG_OLD.md and
# friends match too — at the cost of also skipping e.g. a changelog_parser.py.
release_doc_names='changelog* license licence copying history news'
release_doc_dirs='changelog .changeset changeset changesets release*'

# List release/legal docs under $1 (default .).
find_release_docs() {
  root="${1:-.}"
  set -f # lists expand unquoted; don't glob release*
  set --
  for n in ${release_doc_names}; do
    set -- "$@" -o -iname "$n" -o -iname "$n.txt" -o -iname "$n.md"
  done
  for d in ${release_doc_dirs}; do
    set -- "$@" -o -ipath "*/$d/*"
  done
  set +f
  shift # drop leading -o
  find "$root" -type f \( "$@" \) -print
}

# NUL-separated list of files codespell should scan: every regular file except
# dotdirs/dotfiles and the release/legal docs above.
list_spell_targets() {
  set -f
  set -- -path '*/.*'
  for d in ${release_doc_dirs}; do
    set -- "$@" -o -type d -iname "$d"
  done
  set -- \( "$@" \) -prune -o -type f
  for n in ${release_doc_names}; do
    set -- "$@" ! -iname "$n" ! -iname "$n.txt" ! -iname "$n.md"
  done
  set +f
  find . "$@" -print0
}

# --- delete mode (used by the approval-gated cleanup job) -------------------
if [ "${INPUT_DELETE_FORK:-false}" = "true" ]; then
  [ -n "${repository}" ] || {
    echo "::error ::repository input is required"
    exit 1
  }
  # Never delete on an unverified slug: it must exist and actually be a fork.
  is_fork="$(gh repo view --json isFork --jq '.isFork' "${repository}" 2>/dev/null || echo missing)"
  if [ "${is_fork}" = missing ]; then
    echo "::notice ::Fork ${repository} not found (nothing to delete)"
    exit 0
  fi
  [ "${is_fork}" = true ] || {
    echo "::error ::${repository} is not a fork; refusing to delete."
    exit 1
  }
  echo "Deleting fork: ${repository}"
  gh repo delete --yes "${repository}"
  step_summary "> [!IMPORTANT]\n> Deleted [${repository}](https://github.com/${repository})"
  echo "::notice ::Deleted fork ${repository}"
  exit 0
fi

[ -n "${repository}" ] || {
  echo "::error ::repository input is required"
  exit 1
}

# --- resolve repository metadata --------------------------------------------
trimmed="${repository%/}"
repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' "${trimmed}")"
repoName="$(gh repo view --json name --jq '.name' "${trimmed}")"
repoUrl="$(gh repo view --json url --jq '.url' "${trimmed}")"
owner="${GITHUB_REPOSITORY_OWNER:-$(gh api user --jq '.login')}"
repoFork="${owner}/${repoName}"
repoForkUrl="https://github.com/${repoFork}"

# A repo cannot be forked into the account that already owns it — ${repoFork} would resolve
# to the target itself. Bail before cloning or spell-checking; pushing to the target is
# never correct.
if [ "$(lower "${owner}")" = "$(lower "${repo%%/*}")" ]; then
  echo "::error ::${repo} is owned by ${owner}; a fork cannot be created. Run this action as a different account."
  exit 1
fi

# Emit outputs early so the cleanup job has them even when nothing changes.
set_output repoFork "${repoFork}"
set_output repoForkUrl "${repoForkUrl}"
step_summary "### [${repo}](${repoUrl})\n"
echo "Target: ${repo} (${repoUrl})"

# --- clone the target -------------------------------------------------------
workdir="$(mktemp -d)"
gh repo clone "${repo}" "${workdir}" -- --depth=1
cd "${workdir}"

# --- run codespell ----------------------------------------------------------
# Normalize ignore/skip (space- or comma-separated) into comma lists.
ignore_words="$(printf '%s' "${ignore}" | tr ',' ' ' | xargs | tr ' ' ',')"
skip_list="$(printf '%s' "${skip}" | tr ',' ' ' | xargs | tr ' ' ',')"

set -- --count --quiet-level 11 --summary --write-changes
[ -n "${ignore_words}" ] && set -- "$@" --ignore-words-list "${ignore_words}"
[ -n "${skip_list}" ] && set -- "$@" --skip "${skip_list}"

step_summary "#### arguments\n- skip: ${skip_list:-<none>}\n- ignore: ${ignore_words:-<none>}\n"

# codespell exits non-zero when it finds/writes fixes; don't abort (was continue-on-error).
# Release/legal docs are excluded — they quote historical text verbatim.
list_spell_targets | xargs -0 -r codespell "$@" || true

# Remove the matchers, so no other jobs hit them.
if [ -n "${GITHUB_WORKSPACE:-}" ]; then
  echo "::remove-matcher owner=codespell-matcher-default::"
  echo "::remove-matcher owner=codespell-matcher-specified::"
fi

# --- detect changes ---------------------------------------------------------
if git diff --exit-code --quiet; then
  echo "No spelling errors found."
  exit 0
fi
echo "Spelling fixes written."

# --- git identity + push credentials ----------------------------------------
git config user.name "${owner}"
git config user.email "$(gh api user/public_emails --jq '.[0].email' 2>/dev/null || echo "${owner}@users.noreply.github.com")"
gh auth setup-git

# --- fork, commit, push -----------------------------------------------------
# `gh repo fork` exits 0 when the fork already exists and non-zero for reasons that are not
# fatal, so its status is advisory only. The identity check below is the real gate: the slug
# must exist, be a fork, and name the target as its parent — otherwise a same-named unrelated
# repo (or the target itself) would take the force push. Forks are eventually consistent, so
# poll briefly. Note `gh`'s parent object exposes owner.login/name — there is no
# nameWithOwner field on it, so the slug is composed by hand.
gh repo fork "${repo}" --clone=false --default-branch-only \
  || echo "fork command returned non-zero; verifying fork state"

parent=''
n=0
while [ "${n}" -lt 5 ]; do
  parent="$(gh repo view --json isFork,parent --jq 'select(.isFork) | "\(.parent.owner.login)/\(.parent.name)"' "${repoFork}" 2>/dev/null || true)"
  [ "$(lower "${parent}")" = "$(lower "${repo}")" ] && break
  n=$((n + 1))
  [ "${n}" -lt 5 ] && sleep 3
done
[ "$(lower "${parent}")" = "$(lower "${repo}")" ] || {
  echo "::error ::${repoFork} is not a fork of ${repo} (parent: ${parent:-none}); refusing to push."
  exit 1
}

git remote set-url origin "${repoForkUrl}.git"

branch='docs/fix-spelling'
git switch --force-create "${branch}"
git add -A
git commit --signoff --message 'docs: correct spelling'
git push --force origin "${branch}"

step_summary "### [${repoFork}](${repoForkUrl}/pull/new/${branch})\n"
echo "Pushed fixes to ${repoForkUrl} (branch ${branch})"
echo "::notice ::Open a PR from ${repoFork} at ${repoForkUrl}/pull/new/${branch}"
