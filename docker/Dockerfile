# koru-benchmarks bench rig — reproducible Linux environment with ALL
# reference toolchains, for correctness runs anywhere and perf runs on a
# dedicated quiesced box (e.g. a DigitalOcean droplet).
#
#   docker build -t koru-bench -f docker/Dockerfile .
#   docker run --rm koru-bench ./run.sh          # correctness gate (all kernels through koruc)
#   docker run --rm koru-bench ./bench.sh        # perf board (hyperfine; only trust timing on a quiet host)
#
# Pin toolchain provenance with build args:
#   --build-arg KORU_REF=main --build-arg OSPREY_REF=main
#
# Discipline note: Docker gives a reproducible ENVIRONMENT, not stable TIMING.
# Numbers from a shared/loaded host are not board-worthy; the results artifact
# records machine + koru commit either way.

FROM debian:bookworm-slim

ARG ZIG_VERSION=0.15.2
ARG KORU_REF=main
ARG OSPREY_REF=main
ARG RUST_VERSION=stable

# Reference toolchains from apt where the distro version is acceptable
# (versions are recorded in the results artifact, so "old but honest" is fine):
# cc (gcc), ghc, ocamlopt, hyperfine, python3. LLVM/clang + make for Osprey.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils git make build-essential \
        ghc ocaml python3 \
        llvm clang \
        libssl-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Rust via rustup — Osprey's compiler is a Rust crate and apt's rustc is too
# old for arbitrary crates; this also gives the rust reference column a
# current, recorded version.
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION} --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# Zig — koruc shells out to `zig build` (stages B and D).
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) zarch=x86_64 ;; \
        arm64) zarch=aarch64 ;; \
        *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${zarch}-linux-${ZIG_VERSION}.tar.xz" -o /tmp/zig.tar.xz; \
    mkdir -p /opt/zig; \
    tar -xJf /tmp/zig.tar.xz -C /opt/zig --strip-components=1; \
    rm /tmp/zig.tar.xz; \
    ln -s /opt/zig/zig /usr/local/bin/zig; \
    zig version

# hyperfine from upstream release — Debian bookworm's apt build is 1.15, which
# predates the `-N` / --shell=none flag the board protocol uses (added 1.16);
# with the old build EVERY timing errors out (the whole board comes back
# hf-err). Pin a current binary, same pattern as zig.
ARG HF_VERSION=1.19.0
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) hfarch=x86_64 ;; arm64) hfarch=aarch64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac; \
    curl -fsSL "https://github.com/sharkdp/hyperfine/releases/download/v${HF_VERSION}/hyperfine-v${HF_VERSION}-${hfarch}-unknown-linux-gnu.tar.gz" -o /tmp/hf.tgz; \
    tar -xzf /tmp/hf.tgz -C /tmp; \
    mv "/tmp/hyperfine-v${HF_VERSION}-${hfarch}-unknown-linux-gnu/hyperfine" /usr/local/bin/hyperfine; \
    rm -rf /tmp/hf.tgz /tmp/hyperfine-v*; \
    hyperfine --version

# Osprey from source (github.com/Nimblesite/osprey, MIT) — completes the
# reference board's osprey column. `make build` = C runtime archives +
# cargo build --release; binary lands at target/release/osprey.
# Best-effort: Osprey is one OPTIONAL reference column. bench.sh reports a
# missing toolchain as ABSENT (honest, never faked), so an Osprey build failure
# must NOT sink the whole rig — the koru/c/rust/haskell board still stands.
RUN set -eux; \
    git clone --depth 1 --branch "${OSPREY_REF}" https://github.com/Nimblesite/osprey /opt/osprey-src; \
    cd /opt/osprey-src; \
    if make build && [ -x target/release/osprey ]; then \
        ln -s /opt/osprey-src/target/release/osprey /usr/local/bin/osprey; \
        osprey --version || true; \
    else \
        echo "WARNING: osprey build failed on this image — osprey column will be ABSENT"; \
    fi

# koruc from source — the toolchain under test, pinned by KORU_REF.
RUN set -eux; \
    git clone --branch "${KORU_REF}" https://github.com/korulang/koru /opt/koru; \
    cd /opt/koru; \
    zig build; \
    /opt/koru/zig-out/bin/koruc --version || true
ENV KORUC=/opt/koru/zig-out/bin/koruc

# The benchmark suite itself — copied last (changes most often).
WORKDIR /bench
COPY . /bench

CMD ["./run.sh"]
