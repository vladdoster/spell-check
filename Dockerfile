FROM python:3.12-slim

# git + gh (GitHub CLI, from GitHub's official apt repo). glibc base keeps
# codespell, gh, and git coexisting cleanly and any JS actions working.
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl git; \
  install -m 0755 -d /etc/apt/keyrings; \
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
  "$(dpkg --print-architecture)" >/etc/apt/sources.list.d/github-cli.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends gh; \
  rm -rf /var/lib/apt/lists/*

# codespell (pinned for reproducibility; replaces the former `uvx codespell`).
RUN pip install --no-cache-dir codespell==2.4.2

COPY entrypoint.sh codespell-problem-matcher.json /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
