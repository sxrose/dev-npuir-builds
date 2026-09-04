FROM ascend-builder:latest AS build

ARG TRITON_BRANCH
ARG TRITON_REPO_URL

WORKDIR /workspace
RUN git clone -b ${TRITON_BRANCH} ${TRITON_REPO_URL} .

ENV CC="clang"
ENV CXX="clang++"
ENV TRITON_BUILD_PROTON="OFF"
ENV TRITON_WHEEL_NAME="triton-ascend"
ENV TRITON_APPEND_CMAKE_ARGS="-DCMAKE_LINKER=lld -DTRITON_BUILD_UT=OFF"

RUN python setup_ascend.py bdist_wheel

RUN mkdir -p /dist && \
    cp dist/*.whl /dist/

FROM scratch
COPY --from=build /dist /dist

