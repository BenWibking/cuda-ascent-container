FROM nvidia/cuda:12.8.0-devel-ubuntu24.04

RUN apt-get clean && apt-get update -y && \
    DEBIAN_FRONTEND="noninteractive" TZ=America/New_York apt-get install -y --no-install-recommends git python3-minimal libpython3-stdlib bc hwloc wget openssh-client python3-numpy python3-h5py python3-matplotlib python3-scipy python3-pip lcov curl cuda-nsight-systems-12-6 cmake ninja-build libpython3-dev gcc-11 g++-11 emacs nvi sphinx-doc python3-sphinx-rtd-theme python3-sphinxcontrib.bibtex python3-sphinx-copybutton && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 10

RUN g++ --version

RUN pip3 install unyt --break-system-packages

RUN pip3 install blosc2 --break-system-packages

# for Codespaces/VSCode Sphinx support
RUN pip3 install esbonio --break-system-packages

# h5py from the repo is incompatible with the default numpy 2.1.0
# Downgrading is not the cleanest solution, but it works...
# see https://stackoverflow.com/questions/78634235/numpy-dtype-size-changed-may-indicate-binary-incompatibility-expected-96-from
RUN pip3 install numpy==1.26.4 --break-system-packages

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key| apt-key add - && \
    echo "deb http://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" > /etc/apt/sources.list.d/llvm.list

RUN apt-get clean && apt-get update -y && \
    DEBIAN_FRONTEND="noninteractive" TZ=America/New_York apt-get install -y --no-install-recommends clang-20 llvm-20 libomp-20-dev clangd-20 && \
    rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.4.tar.bz2 && \
    tar xjf openmpi-4.1.4.tar.bz2 && \
    cd openmpi-4.1.4 && \
    ./configure --prefix=/opt/openmpi --disable-mpi-fortran --disable-oshmem --with-cuda && \
    make -j16 && \
    make install && \
    cd / && \
    rm -rf /tmp/openmpi*

ENV LD_LIBRARY_PATH=/opt/openmpi/lib:$LD_LIBRARY_PATH \
    PATH=/opt/openmpi/bin:$PATH

RUN cd /tmp && \
    wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.2/src/hdf5-1.12.2.tar.gz && \
    tar xzf hdf5-1.12.2.tar.gz && \
    cd hdf5-1.12.2 && \
    mkdir -p /usr/local/hdf5/serial /usr/local/hdf5/parallel && \
    ./configure --prefix=/usr/local/hdf5/serial --enable-hl --enable-build-mode=production && make -j16 && make install && make clean && \
    ./configure --prefix=/usr/local/hdf5/parallel --enable-hl --enable-build-mode=production --enable-parallel && make -j16 && make install && \
    cd / && \
    rm -rf /tmp/hdf5-1.12.2*

RUN mkdir /tmp/build-adios2 && cd /tmp/build-adios2 && \
    wget https://github.com/ornladios/ADIOS2/archive/refs/tags/v2.10.1.tar.gz && \
    tar xzf v2.10.1.tar.gz && \
    mkdir adios2-build && cd adios2-build && \
    cmake ../ADIOS2-2.10.1 -DADIOS2_USE_Blosc2=ON -DADIOS2_USE_Fortran=OFF && \
    make -j 16 && make install && \
    cd / && \
    rm -rf /tmp/build-adios2

# commit version is dev branch on 2024-08-30
RUN mkdir /tmp/build-openpmd && cd /tmp/build-openpmd && \
    wget https://github.com/openPMD/openPMD-api/archive/1c7d7ff.tar.gz && \
    tar xzf 1c7d7ff.tar.gz && \
    mkdir openPMD-api-build && cd openPMD-api-build && \
    cmake ../openPMD-api-1c7d7ffc5ef501e1d2dcbd5169b3e5eff677b399 -DopenPMD_USE_PYTHON=ON -DPython_EXECUTABLE=$(which python3) -DopenPMD_USE_ADIOS2=ON && \
    cmake --build . -j 16 && \
    cmake --build . --target install && \
    cd / && \
    rm -rf /tmp/build-openpmd

RUN mkdir /tmp/build-ascent

COPY ascent_build.patch /tmp/build-ascent

## NOTE: with enable_cuda=ON, you need a Docker VM with a LARGE amount of RAM (at least 15 GB RAM, 4 GB swap)

# commit version is dev branch on 2025-04-10
RUN cd /tmp/build-ascent && \
    wget https://github.com/Alpine-DAV/ascent/archive/4da1379.tar.gz && \
    tar xzf 4da1379.tar.gz -C . --strip-components=1 && \
    wget https://github.com/LLNL/blt/archive/refs/tags/v0.6.2.tar.gz && \
    tar xzf v0.6.2.tar.gz -C ./src/blt --strip-components=1 && \
    cd ./scripts/build_ascent && \
    patch -p1 build_ascent.sh /tmp/build-ascent/ascent_build.patch && \
    env enable_cuda=ON enable_mpi=ON build_hdf5=false build_silo=false bash build_ascent.sh && \
    cd / && \
    rm -rf /tmp/ascent_build

# create new user
RUN groupadd -g 109 render
RUN useradd --create-home --shell /bin/bash -G render,sudo ci

USER ci

WORKDIR /home/ci
