FROM quay.io/pypa/manylinux2014_x86_64

LABEL 'org.opencontainers.version'=1.2
LABEL 'org.opencontainers.image.created'='2025-05-18'
LABEL 'org.opencontainers.image.description'='Ready to use image for building Nuke plugins.'
LABEL 'org.opencontainers.license'='MIT'
LABEL 'org.opencontainers.url'='https://codeberg.org/gillesvink/NukeDockerBuild'
LABEL 'com.nukedockerbuild.based_on'='quay.io/pypa/manylinux2014_x86_64'
LABEL 'com.nukedockerbuild.operating_system'='linux'
LABEL 'com.nukedockerbuild.nuke_version'=14.1
LABEL 'com.nukedockerbuild.nuke_source'='https://thefoundry.s3.amazonaws.com/products/nuke/releases/14.1v7/Nuke14.1v7-linux-x86_64.tgz'

ARG NUKE_SOURCE_FILES

COPY $NUKE_SOURCE_FILES /usr/local/nuke_install

RUN yum install mesa-libGLU-devel -y \
  && yum clean all \
  && rm -rf /var/cache/yum

RUN curl -LO https://github.com/Kitware/CMake/releases/download/v3.29.3/cmake-3.29.3-linux-x86_64.sh \
  && chmod +x cmake-3.29.3-linux-x86_64.sh \
  && ./cmake-3.29.3-linux-x86_64.sh --prefix=/usr/local --skip-license \
  && rm cmake-3.29.3-linux-x86_64.sh \
  && ln -s /usr/local/bin/cmake /usr/local/bin/cmake3

WORKDIR /nuke_build_directory

ENV CMAKE_PREFIX_PATH=/usr/local/nuke_install \
  CXXFLAGS=-std=c++17
ENV NUKE_VERSION=14.1