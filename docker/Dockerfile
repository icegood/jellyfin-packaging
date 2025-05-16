# Docker build arguments
ARG DOTNET_VERSION=8.0
ARG NODEJS_VERSION=20

# https://github.com/intel/compute-runtime/releases
ARG GMMLIB_VER=22.7.0
# >= Gen12 graphics (current)
ARG IGC2_VER=2.10.8
ARG IGC2_BUILD=18926
ARG NEO_VER=25.13.33276.16
# <= Gen11 graphics (legacy)
ARG IGC1_LEGACY_VER=1.0.17537.20
ARG NEO_LEGACY_VER=24.35.30872.22

# https://github.com/tsukumijima/libmali-rockchip
ARG MALI_PKG_VER=1.9-1_arm64
ARG MALI_PKG_TAG=v1.9-1-2131373
ARG MALI_PKG_CFG=valhall-g610-g24p0-gbm

# Debian architecture (amd64, arm64, armhf), set by build script
ARG PACKAGE_ARCH
# Dotnet architeture (x64, arm64, arm), set by build script
ARG DOTNET_ARCH
# QEMU architecture (x86_64, aarch64, arm), set by build script
ARG QEMU_ARCH
# Base Image architecture (amd64, arm64v8, arm32v7), set by build script
ARG IMAGE_ARCH=x64
# Target platform architecture (amd64, arm64/v8, arm/v7), set by build script
ARG TARGET_ARCH

# Jellyfin version
ARG JELLYFIN_VERSION
 ARG DOTNET_VERSION
#
# Build the server artifacts
#
FROM jellyfin_backend_runner_stage:ice_master-amd64 AS server

ARG DOTNET_ARCH
ARG ARTIFACT_DIR=/server

ARG CONFIG=Release
ENV CONFIG=${CONFIG}
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

WORKDIR /opt/jellyfin-server

USER root

RUN mkdir -p ${ARTIFACT_DIR}

RUN chmod 777 ${ARTIFACT_DIR}

USER vscode

RUN dotnet publish Jellyfin.Server --arch ${DOTNET_ARCH} --configuration ${CONFIG} \
    --output="${ARTIFACT_DIR}" --self-contained -p:DebugSymbols=false -p:DebugType=none

# qemu
FROM multiarch/qemu-user-static:x86_64-${QEMU_ARCH} AS qemu


#
# Build the final combined image
#
FROM --platform=linux/${TARGET_ARCH} amd64/debian:bookworm-slim@sha256:28c1e76b454bb65a9138a2562708e7fa3a937ae88a36b30fe8a12e3e1d447ce3 AS combined

ARG GMMLIB_VER
ARG IGC2_VER
ARG IGC2_BUILD
ARG NEO_VER
ARG IGC1_LEGACY_VER
ARG NEO_LEGACY_VER

ARG MALI_PKG_VER
ARG MALI_PKG_TAG
ARG MALI_PKG_CFG

ARG PACKAGE_ARCH
ARG DOTNET_ARCH
ARG QEMU_ARCH

# Copy the QEMU runtime
COPY --from=qemu /usr/bin/* /usr/bin

# Set the health URL
ENV HEALTHCHECK_URL=http://localhost:8096/health

# Default environment variables for the Jellyfin invocation
ENV DEBIAN_FRONTEND="noninteractive" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    JELLYFIN_DATA_DIR="/config" \
    JELLYFIN_CACHE_DIR="/cache" \
    JELLYFIN_CONFIG_DIR="/config/config" \
    JELLYFIN_LOG_DIR="/config/log" \
    JELLYFIN_WEB_DIR="/jellyfin/jellyfin-web" \
    JELLYFIN_FFMPEG="/opt/ffmpeg_ice/bin/ffmpeg"

# required for fontconfig cache
ENV XDG_CACHE_HOME=${JELLYFIN_CACHE_DIR}

# https://github.com/dlemstra/Magick.NET/issues/707#issuecomment-785351620
ENV MALLOC_TRIM_THRESHOLD_=131072

# https://github.com/NVIDIA/nvidia-docker/wiki/Installation-(Native-GPU-Support)
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

# Install dependencies:
RUN apt-get update \
 && apt-get install --no-install-recommends --no-install-suggests --yes \
    ca-certificates \
    gnupg \
    curl \
    apt-transport-https \
 && apt-get update \
 && apt-get install --no-install-recommends --no-install-suggests --yes \
    openssl \
    locales \
    libfontconfig1 \
    libfreetype6 \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen \
 && apt-get remove gnupg apt-transport-https --yes \
 && apt-get clean autoclean --yes \
 && apt-get autoremove --yes \
 && rm -rf /var/cache/apt/archives* /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y imagemagick && apt-get clean

RUN mkdir -p ${JELLYFIN_DATA_DIR} ${JELLYFIN_CACHE_DIR} \
 && chmod 777 ${JELLYFIN_DATA_DIR} ${JELLYFIN_CACHE_DIR}

RUN mkdir -p /opt/ffmpeg_ice

COPY --from=server /opt/ffmpeg_ice /opt/ffmpeg_ice

COPY --from=server /usr/lib/x86_64-linux-gnu/libvpx*.so* /usr/lib/x86_64-linux-gnu/libmp3lame*.so* \
    /usr/lib/x86_64-linux-gnu/libnuma*.so* /usr/lib/x86_64-linux-gnu/libx26*.so* \
    /usr/lib/x86_64-linux-gnu/libxcb*.so* /usr/lib/x86_64-linux-gnu/libfontconfig*.so* \
    /usr/lib/x86_64-linux-gnu/libxvid*so* /usr/lib/x86_64-linux-gnu

COPY --from=server /server /jellyfin

# don't need middle container, instead copy eight from context 
# however web container should guarantee to get .dist-build properly
COPY jellyfin-web/.dist-build /jellyfin/jellyfin-web

ARG JELLYFIN_VERSION
LABEL "org.opencontainers.image.source"="https://github.com/icegood/jellyfin-packaging"
LABEL "org.opencontainers.image.title"="Jellyfin (icegood)"
LABEL "org.opencontainers.image.description"="The Free Software Media System"
LABEL "org.opencontainers.image.documentation"="https://jellyfin.org/docs/"
LABEL "org.opencontainers.image.version"="${JELLYFIN_VERSION}"
LABEL "org.opencontainers.image.url"="https://jellyfin.org"

EXPOSE 8096
RUN apt-get update && apt-get install libicu72
RUN apt-get update && apt-get install -y less net-tools iproute2 && apt-get clean
VOLUME ${JELLYFIN_DATA_DIR} ${JELLYFIN_CACHE_DIR}
# override by "/jellyfin/jellyfin" in prod. Locally should be checked right from inside as int test
CMD ["sh", "-c", "tail -f /dev/null"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
     CMD curl --noproxy 'localhost' -Lk -fsS "${HEALTHCHECK_URL}" || exit 1
