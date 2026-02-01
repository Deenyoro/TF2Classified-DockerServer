# TF2 Classified Dedicated Server
#
# Game files download at RUNTIME into persistent volumes (~20GB first run).
# The image itself is just SteamCMD + runtime deps (~500MB).
# Configure everything in .env

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# SteamCMD is 32-bit — enable i386 and pull in Source engine runtime deps.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      tar \
      gzip \
      unzip \
      lib32gcc-s1 \
      lib32stdc++6 \
      lib32z1 \
      libbz2-1.0:i386 \
      libcurl3t64-gnutls:i386 \
      libsdl2-2.0-0:i386 \
      procps \
      tmux \
 && rm -rf /var/lib/apt/lists/*

# Create unprivileged user for srcds
ARG PUID=1000
ARG PGID=1000
RUN groupadd -g ${PGID} srcds \
 && useradd -u ${PUID} -g srcds -m -d /home/srcds -s /bin/bash srcds

# Install SteamCMD from Valve directly
RUN mkdir -p /opt/steamcmd \
 && curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
    | tar -xzC /opt/steamcmd \
 && /opt/steamcmd/steamcmd.sh +quit \
 && mkdir -p /home/srcds/.steam/sdk64 \
 && chown -R srcds:srcds /opt/steamcmd /home/srcds

# Data mount points
RUN mkdir -p /data/tf /data/classified /data/cfg /data/addons /data/maps /data/logs /data/demos \
 && chown -R srcds:srcds /data

COPY --chown=srcds:srcds scripts/ /opt/scripts/
RUN chmod +x /opt/scripts/*.sh

USER srcds
WORKDIR /home/srcds

ENV STEAMCMD_DIR=/opt/steamcmd \
    TF2_DIR=/data/tf \
    CLASSIFIED_DIR=/data/classified \
    SERVER_DATA=/data

EXPOSE 27015/udp 27015/tcp

# start-period is generous because first boot downloads ~20GB via SteamCMD
HEALTHCHECK --interval=60s --timeout=10s --start-period=900s --retries=3 \
    CMD pgrep -f srcds_linux64 > /dev/null || exit 1

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
