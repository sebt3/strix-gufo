# strix-gufo

[gufo](https://github.com/gufo-org/gufo) inference server for AMD Strix Halo
(gfx1151), built from the community fork
[mikealanni/gufo](https://github.com/mikealanni/gufo) (`fork-enhancements`).

The fork adds what upstream does not carry: Qwen3.6-35B-A3B (embedded MTP head,
DFlash2, automatic speculation), block-sparse attention for long contexts and an
optional XDNA2 NPU prefill. Its pull requests to upstream were not merged, so it
stays a fork to follow.

## Build

Nix build from the fork's own `flake.nix` (nixos-unstable pinned by `flake.lock`),
then the package closure is copied into a plain Debian runtime.

- **GPU only.** The NPU path is not compiled in. It needs XRT and the GPU fabric
  clock held at its top level, otherwise the machine can hang.
- `GUFO_REF` is a commit SHA. Bump it deliberately, together with `.tags`.
- `GUFO_OUTPUT` selects the flake output (`default`, or `release` for a version
  label instead of `development`).

```sh
docker build -t strix-gufo:dev .
docker run --rm strix-gufo:dev gufo --version
```

## Run

```sh
gufo serve llm --model /models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf \
  --speculative mtp --mtp-model embedded
```

| Environment | Effect |
| --- | --- |
| `GUFO_QWEN_SPARSE_ATTN=1` | block-sparse attention for 27B / 35B-A3B (approximate, flat with depth). Unset = exact dense attention |
| `GUFO_PREFILL_TILE` | prefill tile (default 16384) |

The container needs `/dev/dri` and `/dev/kfd`.
