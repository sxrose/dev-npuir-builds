# AscendNPU-IR build image

Standalone Docker build environment for AscendNPU-IR and the Triton-Ascend
wheel. The image contains the toolchain; CANN and the source trees live on the
host and are mounted at runtime, so they are never baked into the image.

## Repository layout

The repository is self-contained. The scripts resolve their own location, so
the checkout can live anywhere:

```text
dev-npuir-builds/
  Dockerfile              # build context is the repository root
  build-image.sh          # build the builder image
  setup-cann.sh           # install CANN into a host directory (non-root)
  run.sh                  # run a command / shell inside the image
  scripts/                # copied into the image as /usr/local/bin/*
    build-llvm.sh
    build-compiler.sh
    build-wheel.sh
    pack-compiler.sh
  README.md
```

By default the source checkouts and CANN are expected next to the repository:

```text
~/Work/
  dev-npuir-builds/       # this repository
  AscendNPU-IR/           # mounted as /workspace/AscendNPU-IR
  triton-ascend/          # mounted as /workspace/triton-ascend
  cann/                   # CANN home, mounted as /opt/Ascend/cann
```

## Build the image

The image builds AscendNPU-IR against glibc 2.31 (Ubuntu 20.04). Clang 18,
LLD 18 and `mold` are used for both AscendNPU-IR and Triton-Ascend builds.
Python 3.11 (the latest supported by Triton-Ascend) is built from the official
CPython source tarball and verified against a pinned SHA256
(`PYTHON_VERSION`/`PYTHON_SHA256`), because Ubuntu 20.04 ships only Python 3.8
and the third-party deadsnakes PPA no longer builds for focal.

`mold` is not packaged for Ubuntu 20.04, so the official release tarball is
downloaded and verified against a pinned SHA256 (`MOLD_VERSION`/`MOLD_SHA256`
build args). Bump both together when upgrading.

```bash
./build-image.sh
```

CANN is not part of the image; it is installed by `setup-cann.sh` on first use
(see below).

## CANN setup

`setup-cann.sh` downloads CANN (~2 GB), caches the installer under
`../.cann-pkg/`, and installs it into `../cann` (`CANN_HOME`). `run.sh` calls
it automatically when `CANN_HOME/set_env.sh` is missing, so usually you do not
need to run it by hand:

```bash
./setup-cann.sh
```

The installation runs **inside the container under your own uid, not as
root**, with `--whitelist=toolkit`. This installs the toolkit only and never
the driver or firmware, so no kernel modules are touched.

Override the version with `CANN_URL`, and optionally enforce integrity with
`CANN_SHA256`:

```bash
CANN_URL=https://ascend-cann-open.obs.cn-north-4.myhuaweicloud.com/CANN/CANN-9.0.0-A5/Ascend-cann_9.0.0_linux-x86_64.run \
CANN_SHA256=<sha256> \
./setup-cann.sh
```

## Run

Start an interactive shell with both checkouts mounted:

```bash
./run.sh
```

Inside the container these aliases are available:

```text
build-llvm      # build the upstream LLVM 22 required by Triton-Ascend
build-compiler  # build AscendNPU-IR and the template library
build-wheel     # build a Triton-Ascend wheel
pack-compiler   # create a .tar.zst with bishengir-compile and *.bc
```

Or run a single command without an interactive shell:

```bash
./run.sh build-llvm.sh
./run.sh build-compiler.sh --build-type Release
./run.sh build-wheel.sh
./run.sh pack-compiler.sh
```

## Source locations

`run.sh` finds the checkouts next to the repository by default. Override them
with environment variables:

```bash
IR_ROOT=/path/to/AscendNPU-IR \
TRITON_ROOT=/path/to/triton-ascend \
./run.sh build-wheel.sh
```

| Variable | Default | Purpose |
| --- | --- | --- |
| `IMAGE` | `ascendnpu-ir-ubuntu20-builder` | Image tag used by all scripts |
| `IR_ROOT` | `../AscendNPU-IR` | AscendNPU-IR checkout mounted at `/workspace/AscendNPU-IR` |
| `TRITON_ROOT` | `../triton-ascend` | Triton-Ascend checkout mounted at `/workspace/triton-ascend` |
| `LLVM_SRC` | `../llvm-project` | Upstream LLVM checkout mounted at `/workspace/llvm-project` |
| `LLVM_INSTALL` | `../llvm-install` | Upstream LLVM install mounted at `/workspace/llvm-install` |
| `CANN_HOME` | `../cann` | CANN home mounted at `/opt/Ascend/cann` |
| `CANN_URL` | CANN 9.0.0 A5 `.run` | Installer URL used by `setup-cann.sh` |
| `CANN_SHA256` | empty | Optional SHA256 checked before installing CANN |
| `CANN_PKG_DIR` | `../.cann-pkg` | Host cache for the CANN installer |
| `BUILD_DIR` | `build-ubuntu20` | Build directory inside `IR_ROOT` |
| `CACHE_HOME` | `~/.cache/dev-npuir-builds` | Host directory bind-mounted as the container home; empty disables it |

## Persistence

The container itself is removed after every run (`docker run --rm`). This is
intentional: the source trees, build outputs and CANN live on host bind mounts
and survive, and the toolchain lives in the image.

To keep the `ccache` cache (and the rest of the container home) across runs,
the host directory `~/.cache/dev-npuir-builds/home` is bind-mounted at
`/home/user` and used as `HOME`, so ccache lands in `/home/user/.ccache` inside
the container and in `~/.cache/dev-npuir-builds/home/.ccache` on the host. It
survives `--rm`, is private to the host user, and is never shared with other
users on the machine. No docker volume is used.

Reset the cache by removing the directory:

```bash
rm -rf ~/.cache/dev-npuir-builds
```

Set `CACHE_HOME=` (empty) to run without a persistent home (uses `HOME=/tmp`
inside the container), or point it at a different host directory.

## LLVM build

Triton-Ascend builds against upstream LLVM 22 (`f6ded0be...`) plus the
`third_party/ascend/patch/llvm_patch_f6ded0b.patch` patch. Neither distributed
prebuilt works inside this Ubuntu 20.04 image (`ubuntu-x64` needs glibc 2.32+,
`almalinux-x64` needs a newer libstdc++), so LLVM is built locally:

```bash
./run.sh build-llvm.sh
```

The source revision is read from `triton-ascend/cmake/llvm-hash.txt`: the
checkout is cloned/checked out to that commit (and updated when it changes),
then patched with the matching `llvm_patch_*.patch`. The result is installed to
`LLVM_INSTALL` (`../llvm-install` on the host) and reused by `build-wheel.sh`.
The script always syncs and builds; pass `--skip-if-fresh` to make it a no-op
when `LLVM_INSTALL` already matches the pinned revision and build options
(zlib/zstd are disabled so lld's config does not require `ZLIB::ZLIB`).

## Compiler build

Initialize the submodules before the first build:

```bash
git -C "$IR_ROOT" submodule update --init --recursive
./run.sh build-compiler.sh --build-type Release --apply-patches
```

The generated installation is in `build-ubuntu20/install`. `pack-compiler.sh`
packs `bin/bishengir-compile` and `lib/*.bc` into
`build-ubuntu20/bishengir-compiler.tar.zst` with paths relative to the archive
root.

## Triton-Ascend wheel

If `LLVM_INSTALL` is missing or does not match the revision pinned in
`triton-ascend/cmake/llvm-hash.txt`, `build-wheel.sh` builds it automatically
via `build-llvm.sh`:

```bash
./run.sh build-wheel.sh
```

The wheel is written directly to `triton-ascend/` on the host. It is a plain
`linux_x86_64` wheel (`3.6.0.post0+git<short-hash>`): the Ubuntu 20.04 toolchain
(glibc 2.31, GCC 9 libstdc++) cannot be repaired to `manylinux_2_28`, so
`IS_MANYLINUX` must stay off. Install it with `pip install <wheel>` on a target
running a compatible glibc.

The wheel is not installed in the container. It can be installed on a
compatible target with `pip install <wheel>`. Running Triton kernels still
requires matching CANN, TorchNPU, driver, and Ascend hardware on the target
host.

For a different AscendNPU-IR build directory, set `BUILD_DIR`:

```bash
BUILD_DIR=my-build ./run.sh build-wheel.sh
```
