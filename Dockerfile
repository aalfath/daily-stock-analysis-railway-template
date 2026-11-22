# Daily Stock Analysis for Railway.
# Official image, pinned by version and digest. Bump both together (see CHANGELOG.md).
FROM zhulinsen/daily_stock_analysis:v3.35.0@sha256:0a62ca6e930a9c8fdac447d4306a9210166ca4b3eb8896b3a31f457361cf0d95

# The app keeps its settings in a .env file. Keep it on the volume (/app/data) so
# settings saved in the web UI survive redeploys. The web UI is prebuilt in the image.
ENV ENV_FILE=/app/data/runtime.env \
    WEBUI_AUTO_BUILD=false \
    TRUST_X_FORWARDED_FOR=true

COPY railway-start.sh /usr/local/bin/railway-start.sh
RUN chmod 755 /usr/local/bin/railway-start.sh

# Upstream's entrypoint fixes volume ownership, then runs this as the non-root user "dsa".
CMD ["/usr/local/bin/railway-start.sh"]
