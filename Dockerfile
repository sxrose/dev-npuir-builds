FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      mold \
      ccache \
      git \
      ca-certificates \
      curl \
      wget \
      software-properties-common \
      gnupg \
      python3 \
      python3-pip \
      pkg-config \
      xz-utils \
      zstd \
      file \
      zlib1g-dev \
      patchelf \
    && wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/focal/ llvm-toolchain-focal-18 main" \
      > /etc/apt/sources.list.d/llvm.list \
    && add-apt-repository --yes ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends clang-18 lld-18 \
      python3.10 python3.10-dev \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.10 \
    && python3.10 -m pip install --no-cache-dir \
      'cmake>=3.28' 'ninja>=1.12' wheel setuptools pybind11 auditwheel \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/bin:${PATH}"
ENV CC=/usr/bin/clang-18
ENV CXX=/usr/bin/clang++-18
ENV PYTHON=/usr/bin/python3.10

# CANN is installed at runtime into a host directory mounted at /opt/Ascend.
# The install prefix must be writable by the non-root runtime user.
RUN mkdir -p /opt/Ascend && chmod 0777 /opt/Ascend

WORKDIR /workspace

COPY scripts/ /usr/local/lib/ascendnpu-ir-docker/

RUN install -m 0755 /usr/local/lib/ascendnpu-ir-docker/*.sh /usr/local/bin/ \
    && printf '%s\n' \
      '[ -f /opt/Ascend/cann/set_env.sh ] && . /opt/Ascend/cann/set_env.sh' \
      'alias build-compiler="/usr/local/bin/build-compiler.sh"' \
      'alias build-wheel="/usr/local/bin/build-wheel.sh"' \
      'alias pack-compiler="/usr/local/bin/pack-compiler.sh"' \
      >> /etc/bash.bashrc

# The source tree and build directory are supplied by the host at runtime.
ENTRYPOINT ["/bin/bash"]
