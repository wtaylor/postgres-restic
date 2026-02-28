FROM debian:trixie-20260223-slim

RUN apt-get update && apt-get install -y \
  restic \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
