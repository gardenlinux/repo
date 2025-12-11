ARG base
FROM $base
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y aptitude ca-certificates dpkg-dev jq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y gh \
    || (DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y wget \
    && wget https://dqf78g7gefsor.cloudfront.net/debian-snapshot/pool/4af2d243a11c94ade52aa2e66bb28d8a048fc05f95e2f7cb0e0ecad2343ea872/gh_2.46.0-3_amd64.deb -O /tmp/gh.deb \
    && dpkg -i /tmp/gh.deb \
    && rm /tmp/gh.deb)
RUN dpkg --add-architecture amd64 && dpkg --add-architecture arm64 && apt-get update
COPY fetch_releases download_pkgs create_dist /
