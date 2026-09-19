# Compile this HyperHDR tree (Nanoleaf Essentials branch) into a runnable image.
# Uses the official HyperDockerBuilder toolchain, then installs the .deb into Debian.
#
#   docker build -t hyperhdr:nanoleaf .
#   docker compose up -d
#
# On Linux, prefer host networking so SSDP/mDNS can find Nanoleaf devices.
# On Docker Desktop (Windows/macOS), publish ports and enter the strip IP by hand.

ARG ARCH=amd64
ARG DISTRO=debian
ARG DISTRO_VERSION=bookworm

FROM ghcr.io/awawa-dev/${ARCH}/${DISTRO}:${DISTRO_VERSION} AS build
ARG DISTRO_VERSION=bookworm

WORKDIR /hyperhdr
COPY . .

# Upstream dropped this file; the Linux installer still installs it.
RUN if [ ! -f 3RD_PARTY_LICENSES ]; then printf 'See LICENSE\n' > 3RD_PARTY_LICENSES; fi

RUN mkdir -p build \
	&& cd build \
	&& cmake \
		-DPLATFORM=linux \
		-DCMAKE_BUILD_TYPE=Release \
		-DUSE_CCACHE_CACHING=OFF \
		-DENABLE_SYSTRAY=OFF \
		-DENABLE_DEPENDENCY_PACKAGING=ON \
		-DDEBIAN_NAME_TAG=${DISTRO_VERSION} \
		.. \
	&& cmake --build . -j"$(nproc)" --target package

FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
	TZ=UTC

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates tzdata \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=build /hyperhdr/build/HyperHDR*.deb /tmp/hyperhdr.deb
RUN apt-get update \
	&& apt-get install -y --no-install-recommends /tmp/hyperhdr.deb \
	&& rm -f /tmp/hyperhdr.deb \
	&& rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /config

EXPOSE 8090 8092 19400 19444 19445
VOLUME ["/config"]

# -d: debug logs in docker logs. -u: persist config on the volume.
ENTRYPOINT ["/usr/bin/hyperhdr"]
CMD ["-d", "-u", "/config"]
