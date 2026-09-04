# Docker Build Environments

## Ubuntu 20 compiler build

The Ubuntu 20 image builds AscendNPU-IR against glibc 2.31. The source tree
and build output remain on the host:

```bash
docker build -f docker/Dockerfile.ubuntu20 \
  -t ascendnpu-ir-ubuntu20-builder .

./docker/build-ubuntu20.sh --build-type Release
```

For the first build, initialize the submodules before running the script:

```bash
git submodule update --init --recursive
./docker/build-ubuntu20.sh --build-type Release --apply-patches
```

The script also enables the BiShengIR template library and uses the BiSheng
compiler installed from CANN 9.0.0 A5. The installer is downloaded during the
image build. Its confirmation prompt is answered with `yes`.

The image installs Python 3.10 because Triton-Ascend supports Python 3.9 to
3.11, while the default Ubuntu 20 Python is 3.8.

Clang 18 and LLD 18 are installed from the official LLVM repository. `mold` is
also installed and used as the linker for both AscendNPU-IR and Triton-Ascend
builds. This avoids relying on the slower default linker.

The generated installation is in `build-ubuntu20/install`.

The image provides these interactive shell aliases:

```text
build-compiler  # build AscendNPU-IR and the template library
build-wheel     # build a Triton-Ascend wheel
pack-compiler   # create a .tar.zst with bishengir-compile and *.bc
```

Start an interactive container with both checkouts mounted:

```bash
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --volume "$PWD:/workspace/AscendNPU-IR" \
  --volume "$PWD/../triton-ascend:/workspace/triton-ascend" \
  --workdir /workspace/AscendNPU-IR \
  ascendnpu-ir-ubuntu20-builder
```

Inside the container, run for example:

```bash
build-compiler --build-type Release
build-wheel
pack-compiler
```

The archive contains `bin/bishengir-compile` and `lib/*.bc` with paths relative
to the archive root.

## Triton-Ascend wheel

The Triton-Ascend checkout is expected next to this repository by default:

```text
~/Work/AscendNPU-IR
~/Work/triton-ascend
```

Build the AscendNPU-IR image first, then start a container with both
checkouts mounted:

```bash
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --volume "$PWD:/workspace/AscendNPU-IR" \
  --volume "$PWD/../triton-ascend:/workspace/triton-ascend" \
  --workdir /workspace/AscendNPU-IR \
  ascendnpu-ir-ubuntu20-builder
```

Inside the container, run:

```bash
build-wheel
```

The wheel is written directly to `~/Work/triton-ascend`. Its filename includes
the current branch and commit, for example:

```text
triton_ascend-main-a1b2c3d4e5f6-3.6.0.dev....whl
```

The branch and commit are added as a PEP 440 local version suffix, so the
wheel filename remains valid for `pip`.

The alias sets `LLVM_SYSPATH` to the AscendNPU-IR installation and does not
install the wheel in the container.

The wheel is not installed in the container. It can be installed on a
compatible target with
`pip install <wheel>`. Running Triton kernels still requires matching CANN,
TorchNPU, driver, and Ascend hardware on the target host.

For a different AscendNPU-IR build directory, set `BUILD_DIR` inside the
container:

```bash
IR_BUILD_DIR=my-build \
BUILD_DIR=my-build build-wheel
```
