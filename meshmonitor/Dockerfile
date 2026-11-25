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

# HAM DM: the Virtual Node rebuilds every NodeInfo (our own node too) from the DB
# and drops User.is_licensed / is_unmessagable. Android (2.8.4+) allows a DM to a
# node without a public key only when OUR node says is_licensed (DirectMessageRule:
# hasPKC || localIsLicensed), so through MeshMonitor new DMs were blocked in HAM.
# is_unmessagable is passed only when true: absent = the app falls back to the
# role, as with a radio that never set it. Skipped with a warning if upstream changes.
RUN f=/app/dist/server/virtualNodeServer.js; \
    if grep -q "publicKey: node.publicKey ?? undefined," "$f"; then \
      sed -i "s#publicKey: node.publicKey ?? undefined,#publicKey: node.publicKey ?? undefined, isLicensed: node.isLicensed ? true : undefined, isUnmessagable: node.isUnmessagable ? true : undefined,#" "$f" && \
      echo "virtual node licensed patch applied"; \
    else echo "WARN: virtual node licensed patch not applied"; fi; \
    f=/app/dist/server/meshtasticProtobufService.js; \
    if grep -q "publicKey: publicKeyBytes," "$f"; then \
      sed -i "s#publicKey: publicKeyBytes,#publicKey: publicKeyBytes, isLicensed: info.user.isLicensed === true, isUnmessagable: info.user.isUnmessagable === true ? true : undefined,#" "$f" && \
      echo "nodeinfo user licensed patch applied"; \
    else echo "WARN: nodeinfo user licensed patch not applied"; fi

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT [ "/run.sh" ]
