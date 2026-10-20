# ─── Stage 1: Builder ────────────────────────────────────────────────────────
# Builds the gufo fork with its own flake (nixos-unstable pinned by flake.lock),
# the same toolchain upstream uses for gufo-runtime. GPU-only build: the NPU
# (GUFO_ENABLE_NPU, needs XRT and a held fabric clock) is deliberately left out.
# No GPU is needed at build time.
FROM docker.io/nixos/nix:2.24.11 AS builder
# Pin a commit, not a branch: the fork moves daily.
ARG GUFO_REPO=mikealanni/gufo
ARG GUFO_REF=b1b8a3b5cc12a84d1c3b886972f3fec96b331045
ARG GUFO_OUTPUT=default

RUN mkdir -p /etc/nix && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'sandbox = false' \
    'max-jobs = auto' \
    'build-users-group =' >> /etc/nix/nix.conf

RUN nix build "github:${GUFO_REPO}/${GUFO_REF}#${GUFO_OUTPUT}" --no-link --print-out-paths \
      > /tmp/gufo.path \
 && cat /tmp/gufo.path \
 && "$(cat /tmp/gufo.path)/bin/gufo" --version

# Closure of the package: every store path the binaries need (ROCm, ICU, ffmpeg…)
RUN mkdir /closure \
 && nix-store -qR "$(cat /tmp/gufo.path)" > /tmp/closure.list \
 && wc -l /tmp/closure.list \
 && xargs -a /tmp/closure.list -I{} cp -a --parents {} /closure \
 && du -sh /closure

# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM docker.io/library/debian:trixie-slim AS runtime

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /closure/nix /nix
COPY --from=builder /tmp/gufo.path /opt/gufo.path
RUN for b in "$(cat /opt/gufo.path)"/bin/*; do ln -s "$b" /usr/local/bin/"$(basename "$b")"; done \
 && gufo --version

EXPOSE 8080
# /ready answers once the model is loaded and the first kernels are warm
HEALTHCHECK --interval=30s --timeout=5s --start-period=600s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/health || exit 1
CMD ["gufo", "--help"]
