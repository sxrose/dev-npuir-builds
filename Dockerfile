FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG MOLD_VERSION=2.42.1
ARG MOLD_SHA256=6ff270c9bf07d2bec5c98aa324eb7c4daf6a1a4d815c05ff1708049616047855
ARG PYTHON_VERSION=3.11.16
ARG PYTHON_SHA256=91bcdebfdde239a003ae93738a7fce0f9230fee5c4bc2b86f6e6e8c6f98aabe8

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ccache \
      git \
      ca-certificates \
      curl \
      wget \
      gnupg \
      python3 \
      pkg-config \
      xz-utils \
      zstd \
      file \
      zlib1g-dev \
      patchelf \
      libssl-dev \
      libffi-dev \
      libbz2-dev \
      liblzma-dev \
      libsqlite3-dev \
      libreadline-dev \
      libgdbm-dev \
      libnss3-dev \
      uuid-dev \
      libncurses-dev \
      libexpat1-dev \
    && wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
      | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/focal/ llvm-toolchain-focal-18 main" \
      > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends clang-18 lld-18 \
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

# Python 3.10+ is not available in Ubuntu 20.04. Build CPython from the
# official source tarball, verified against a pinned SHA256, instead of
# relying on a third-party PPA.
RUN curl -fsSL --output /tmp/Python.tar.xz \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz" \
    && echo "${PYTHON_SHA256}  /tmp/Python.tar.xz" | sha256sum -c - \
    && tar -C /tmp -xf /tmp/Python.tar.xz \
    && cd "/tmp/Python-${PYTHON_VERSION}" \
    && ./configure --prefix=/usr/local --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && rm -rf /tmp/Python*

RUN /usr/local/bin/python3.11 -m pip install --no-cache-dir \
      'cmake>=3.28' 'ninja>=1.12' wheel setuptools pybind11 auditwheel

ENV PATH="/usr/local/bin:${PATH}"
ENV CC=/usr/bin/clang-18
ENV CXX=/usr/bin/clang++-18
ENV PYTHON=/usr/local/bin/python3.11

WORKDIR /workspace

COPY scripts/ /usr/local/lib/ascendnpu-ir-docker/

RUN install -m 0755 /usr/local/lib/ascendnpu-ir-docker/*.sh /usr/local/bin/ \
    && printf '%s\n' \
      '[ -n "$ASCEND_HOME_PATH" ] && [ -f "$ASCEND_HOME_PATH/set_env.sh" ] && . "$ASCEND_HOME_PATH/set_env.sh"' \
      'alias build-compiler="/usr/local/bin/build-compiler.sh"' \
      'alias build-llvm="/usr/local/bin/build-llvm.sh"' \
      'alias build-wheel="/usr/local/bin/build-wheel.sh"' \
      'alias pack-compiler="/usr/local/bin/pack-compiler.sh"' \
      >> /etc/bash.bashrc

# The source tree and build directory are supplied by the host at runtime.
ENTRYPOINT ["/bin/bash"]
