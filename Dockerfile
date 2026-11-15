# Toolchain (python, git, gh, codespell) comes prebuilt from Dockerfile.base,
# published by the Base Image workflow.
FROM ghcr.io/vladdoster/spell-check-base:latest

COPY --chmod=0755 entrypoint.sh /
COPY codespell-problem-matcher.json /

ENTRYPOINT ["/entrypoint.sh"]
