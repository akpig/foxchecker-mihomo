# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim AS mihomo-fetch
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gzip \
    && rm -rf /var/lib/apt/lists/*
ARG TARGETARCH
ARG MIHOMO_VERSION=v1.19.33
ARG MIHOMO_AMD64_SHA256=386508bfb1c72c43b6a0eda73708ecdce82546581b0ebcb16366c53757c622b6
RUN test "${TARGETARCH}" = "amd64" \
    && asset="mihomo-linux-amd64-compatible-${MIHOMO_VERSION}.gz" \
    && curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${asset}" -o /tmp/mihomo.gz \
    && printf '%s  %s\n' "${MIHOMO_AMD64_SHA256}" /tmp/mihomo.gz | sha256sum -c - \
    && gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo \
    && chmod 0755 /usr/local/bin/mihomo \
    && /usr/local/bin/mihomo -v
RUN mkdir -p /licenses/mihomo \
    && curl -fsSL "https://raw.githubusercontent.com/MetaCubeX/mihomo/${MIHOMO_VERSION}/LICENSE" -o /licenses/mihomo/LICENSE
RUN --network=none --mount=type=bind,source=geoip,target=/geoip \
    set -eu; \
    digest="$(cat /geoip/current.sha512)"; \
    test "${#digest}" -eq 128; \
    case "$digest" in *[!0-9a-f]*) exit 1 ;; esac; \
    archive="/geoip/$digest.mmdb.gz"; \
    printf '%s  %s\n' "$digest" "$archive" | sha512sum -c -; \
    gzip -dc "$archive" > /tmp/country.mmdb

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 65532 checker \
    && useradd --uid 65532 --gid 65532 --no-create-home --home-dir /tmp --shell /usr/sbin/nologin checker \
    && install -d -m 0700 -o 65532 -g 65532 /output
COPY --chmod=0755 foxchecker/foxchecker /usr/local/bin/foxchecker
RUN --network=none /usr/local/bin/foxchecker --version
COPY --from=mihomo-fetch /usr/local/bin/mihomo /usr/local/bin/mihomo
COPY --from=mihomo-fetch /licenses /licenses
COPY --from=mihomo-fetch /tmp/country.mmdb /usr/local/share/foxchecker/country.mmdb
COPY geoip/NOTICE /licenses/geoip/NOTICE
ENV HOME=/tmp
USER 65532:65532
WORKDIR /output
ENTRYPOINT ["/usr/local/bin/foxchecker", "--engine", "mihomo"]
