FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint-replica.sh /usr/local/bin/entrypoint-replica.sh
RUN chmod +x /usr/local/bin/entrypoint-replica.sh

ENTRYPOINT ["entrypoint-replica.sh"]
CMD ["postgres"]
