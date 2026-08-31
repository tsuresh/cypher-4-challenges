# h16 Overboard, Again — the container the player gets a shell in. It is LAUNCHED
# privileged (--privileged / CAP_SYS_ADMIN) by the per-team sandbox, which is the
# vulnerability. The flag lives on the "host" (a nested throwaway sandbox), not here.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      util-linux procps mount curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY exploit.sh /opt/exploit.sh
RUN chmod +x /opt/exploit.sh
# players get an interactive shell here (via ctfd-whale); keep it alive
CMD ["sleep", "infinity"]
