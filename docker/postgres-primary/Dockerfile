FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
COPY ensure-tls.sh /usr/local/bin/ensure-tls.sh
COPY configure-primary.sh /usr/local/bin/configure-primary.sh
COPY initdb/ /docker-entrypoint-initdb.d/

RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh \
    /usr/local/bin/ensure-tls.sh \
    /usr/local/bin/configure-primary.sh \
    /docker-entrypoint-initdb.d/*.sh

ENTRYPOINT ["entrypoint-wrapper.sh"]
CMD ["postgres"]
