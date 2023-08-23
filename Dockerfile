FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as init
WORKDIR /app
# update
# BASE USE UTILITIES + PYTHON
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y wget git sudo python3-pip build-essential

# GET PYTORCH
FROM init as python-env
# install torch and all needed dependencies (CUDA 11.8)
RUN \
    --mount=type=cache,target=/var/cache/python-env \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# OSSIA REPO 
FROM python-env as ossia-dock
RUN \
    --mount=type=cache,target=/var/cache/ossia-repo \
    git clone --recursive -j16 https://github.com/grybouilli/score

# FETCH OSSIA SDK && INSTALL OSSIA DEPENDENCIES
RUN \
    --mount=type=cache,target=/var/cache/ossia-deps \
    cd score && ./tools/fetch-sdk.sh && ./ci/jammy.deps.sh

RUN mkdir build

FROM ossia-dock as score-dock

RUN \
    --mount=type=cache,target=/var/cache/boost-dep \
    apt-get install -y autotools-dev libicu-dev build-essential libbz2-dev libboost-python-dev libboost-numpy-dev

FROM score-dock as score-final
WORKDIR /app/build
RUN cmake ../score                              \
    -GNinja                                     \
    -DCMAKE_C_COMPILER="clang-14"               \
    -DCMAKE_CXX_COMPILER="clang++-14"           \
    -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld"  \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld"     \
    -DCMAKE_BUILD_TYPE=Debug                    \
    -DSCORE_PCH=1                               \
    -DSCORE_DYNAMIC_PLUGINS=1
RUN cmake --build .

FROM score-final as score-final2
RUN \
    --mount=type=cache,target=/var/cache/python-env2 \
    pip3 install scipy librosa matplotlib

FROM score-final2 as score-gui
ENV DISPLAY :0

ENTRYPOINT [ "/bin/bash" ]