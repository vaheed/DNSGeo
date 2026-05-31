ARG POWERADMIN_TAG=stable
FROM poweradmin/poweradmin:${POWERADMIN_TAG}

COPY poweradmin-entrypoint-wrapper.sh /usr/local/bin/poweradmin-entrypoint-wrapper.sh
COPY healthcheck.sh /usr/local/bin/poweradmin-healthcheck.sh
RUN chmod +x /usr/local/bin/poweradmin-entrypoint-wrapper.sh /usr/local/bin/poweradmin-healthcheck.sh

ENTRYPOINT ["/usr/local/bin/poweradmin-entrypoint-wrapper.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
