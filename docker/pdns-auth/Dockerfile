FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tini postgresql-client inotify-tools \
    && install -d /etc/apt/keyrings \
    && curl -fsSL https://repo.powerdns.com/FD380FBB-pub.asc -o /etc/apt/keyrings/auth-50-pub.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/auth-50-pub.asc] http://repo.powerdns.com/debian bookworm-auth-50 main" > /etc/apt/sources.list.d/pdns.list \
    && printf "Package: pdns-*\nPin: origin repo.powerdns.com\nPin-Priority: 600\n" > /etc/apt/preferences.d/auth-50 \
    && apt-get update \
    && apt-get install -y --no-install-recommends pdns-server pdns-backend-pgsql pdns-backend-geoip \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/pdns-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/pdns-healthcheck.sh
RUN chmod +x /usr/local/bin/pdns-entrypoint.sh /usr/local/bin/pdns-healthcheck.sh \
    && mkdir -p /etc/powerdns/pdns.d /var/run/pdns /var/lib/powerdns/mmdb

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/pdns-entrypoint.sh"]
