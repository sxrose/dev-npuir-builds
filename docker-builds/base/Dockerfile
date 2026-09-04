FROM quay.io/pypa/manylinux_2_28

RUN yum install -y \
    make cmake \
    git wget curl \
    patch \
    llvm \
    clang \
    lld \
    zlib-devel

# Install Miniconda and Python 3.11
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

ENV PATH="/opt/conda/bin:$PATH"

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create a Miniconda environment with Python 3.11
RUN conda create -n triton-env python=3.11 -y

# Activate the environment
SHELL ["conda", "run", "-n", "triton-env", "bash", "-c"]

RUN pip install pybind11 ninja

