# i04 Return to Sender — per-team pwn instance (ctfd-whale).
# Builds the No-PIE/no-canary binary and serves it over TCP via socat, one fresh
# process per connection. The flag is written to /flag at start by the entrypoint.
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev && rm -rf /var/lib/apt/lists/*
COPY src/gateway.c /src/gateway.c
RUN gcc -O0 -fno-stack-protector -no-pie -w -o /return-to-sender /src/gateway.c

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends socat && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 ctf
COPY --from=build /return-to-sender /return-to-sender
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh /return-to-sender
EXPOSE 9104
ENTRYPOINT ["/docker-entrypoint.sh"]
