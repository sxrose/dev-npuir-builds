FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG MOLD_VERSION=2.42.1
ARG MOLD_SHA256=6ff270c9bf07d2bec5c98aa324eb7c4daf6a1a4d815c05ff1708049616047855

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
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

# mold is not packaged for Ubuntu 20.04; install the official release and
# verify it against a pinned SHA256.
RUN curl -fsSL --output /tmp/mold.tar.gz \
      "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/mold-${MOLD_VERSION}-x86_64-linux.tar.gz" \
    && echo "${MOLD_SHA256}  /tmp/mold.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/mold.tar.gz --strip-components=1 \
    && rm -f /tmp/mold.tar.gz \
    && ln -s /usr/local/bin/mold /usr/bin/mold \
    && ln -s /usr/local/bin/ld.mold /usr/bin/ld.mold \
    && /usr/local/bin/mold --version

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
