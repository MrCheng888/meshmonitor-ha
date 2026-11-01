FROM ghcr.io/yeraze/meshmonitor:latest

USER root
RUN apk add --no-cache jq curl bash nginx

COPY nginx.conf /etc/nginx/http.d/default.conf

# HA_LOGIN: let /api/auth/status run the auth middleware, so the very first
# page load already recognises the Home Assistant user (otherwise the UI shows
# the password form until a reload — impossible in the HA mobile app).
# Harmless when proxy auth is off. Skipped with a warning if upstream changes.
RUN f=/app/dist/server/routes/authRoutes.js; \
    if grep -q "router.get('/status', async" "$f"; then \
      sed -i "s#router.get('/status', async#router.get('/status', __haOptionalAuth(), async#" "$f" && \
      sed -i "1i import { optionalAuth as __haOptionalAuth } from '../auth/authMiddleware.js';" "$f" && \
      echo "auth status patch applied"; \
    else echo "WARN: auth status patch not applied"; fi

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT [ "/run.sh" ]
