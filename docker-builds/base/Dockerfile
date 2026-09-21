FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    git wget curl \
    patch \
    clang-18 \
    lld-18 \
    zlib1g zlib1g-dev

RUN wget https://github.com/rui314/mold/releases/download/v2.42.1/mold-2.42.1-x86_64-linux.tar.gz && \
    tar xvf ./mold-2.42.1-x86_64-linux.tar.gz && \
    cp -r ./mold-2.42.1-x86_64-linux/bin/* /usr/bin && \
    cp -r ./mold-2.42.1-x86_64-linux/lib/* /usr/lib && \
    cp -r ./mold-2.42.1-x86_64-linux/libexec/* /usr/libexec
    
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

ENV PATH="/opt/conda/bin:$PATH"

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create a Miniconda environment with Python 3.11
RUN conda create -n ascend-builder python=3.11 -y

# Activate the environment
SHELL ["conda", "run", "-n", "ascend-builder", "bash", "-c"]

RUN pip install pybind11 cmake ninja

RUN wget https://ascend-cann-open.obs.cn-north-4.myhuaweicloud.com/CANN/CANN%209.2.0-beta.2/Ascend-cann_9.2.0-beta.2_linux-x86_64.run

RUN bash Ascend-cann_9.2.0-beta.2_linux-x86_64.run --extract=/cann_package --noexec --quiet

RUN bash /cann_package/run_package/cann-bisheng-compiler_9.2.0-beta.2_linux-x86_64.run --full --install-path=/cann

ENV BISHENG_INSTALL_PATH=/cann/cann/bin
