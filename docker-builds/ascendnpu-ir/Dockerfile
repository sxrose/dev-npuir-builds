FROM ascend-builder:latest AS build

ARG NPUIR_BRANCH
ARG NPUIR_REPO_URL

WORKDIR /workspace
RUN git clone -b ${NPUIR_BRANCH} ${NPUIR_REPO_URL} . \
    --recurse-submodules --shallow-submodules

RUN ./build-tools/build.sh \
    --c-compiler clang-18 \
    --cxx-compiler clang++-18 \
    --build-type Release \
    --fast-build \
    --disable-mlir-werror \
    --disable-bishengir-werror \
    --enable-assertion \
    --disable-werror \
    --apply-patches \
    --add-cmake-options "-DLLVM_USE_LINKER=mold" \
    --build-triton -t --bisheng-compiler $BISHENG_INSTALL_PATH 

RUN mkdir -p /dist && \
    cp -r build/ /dist

FROM scratch
COPY --from=build /dist /dist

