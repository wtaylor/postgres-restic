FROM debian:trixie-20260223-slim

LABEL org.opencontainers.image.source=https://github.com/wtaylor/postgres-restic

RUN apt-get update && apt-get install -y \
  restic \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
