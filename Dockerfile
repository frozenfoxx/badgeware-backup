# Base image
FROM ubuntu:24.04

# Information
LABEL maintainer="FrozenFOXX <frozenfoxx@cultoffoxx.net>"

# Variables
ENV HOME=/root \
  APP_DEPS="tini libusb-1.0-0" \
  BUILD_DEPS="ca-certificates cmake g++ git libusb-1.0-0-dev make pkg-config" \
  DEBIAN_FRONTEND=noninteractive \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US.UTF-8 \
  LC_ALL=C.UTF-8 \
  PICOTOOL_VERSION=2.1.1 \
  PICO_SDK_VERSION=2.1.1

# Install packages, build picotool from source, clean up
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends ${BUILD_DEPS} ${APP_DEPS} && \
  git clone --depth 1 --branch ${PICO_SDK_VERSION} https://github.com/raspberrypi/pico-sdk /tmp/pico-sdk && \
  git clone --depth 1 --branch ${PICOTOOL_VERSION} https://github.com/raspberrypi/picotool /tmp/picotool && \
  cmake -S /tmp/picotool -B /tmp/picotool/build \
    -DPICO_SDK_PATH=/tmp/pico-sdk \
    -DPICOTOOL_NO_LIBUSB_FALLBACK=OFF && \
  cmake --build /tmp/picotool/build -- -j"$(nproc)" && \
  cmake --install /tmp/picotool/build && \
  rm -rf /tmp/picotool /tmp/pico-sdk && \
  apt-get remove -y ${BUILD_DEPS} && \
  apt-get autoremove --purge -y && \
  rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY scripts/backup-flash.sh /usr/local/bin/backup-flash.sh
COPY scripts/restore-flash.sh /usr/local/bin/restore-flash.sh

# Expose backups volume
VOLUME ["/backups"]

# Launch process
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
