FROM postgres:17-bookworm

COPY db-init.sh /usr/local/bin/db-init.sh
COPY sql/ /sql/
RUN chmod +x /usr/local/bin/db-init.sh

ENTRYPOINT ["/usr/local/bin/db-init.sh"]
