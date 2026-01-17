# hadolint global ignore=DL3008,DL3013
# syntax=docker/dockerfile:1

ARG TARGETARCH

# ----------------------------------
# Platform Images
# ----------------------------------
# These are configurable at build-time. Reason being,
# we need these language runtimes (and some associated tools)
# to change at-will for testing and matrix builds.
# Sane defaults are provided so someone can just `docker build .`.
# But in production builds, these will always be given externally.
ARG NODE_VERSION=22.22.0
ARG GRADLE_VERSION=8.14.3
ARG JAVA_VERSION=21.0.9_10
FROM node:${NODE_VERSION}-bookworm-slim AS node-src
FROM gradle:${GRADLE_VERSION}-jdk21-noble AS gradle-src
FROM eclipse-temurin:${JAVA_VERSION}-jdk-noble AS jdk-src
# ----------------------------------
# End Platform Images
# ----------------------------------

# ----------------------------------
# General Tool images
# ----------------------------------
# These are images we apply fixed versions to.
# This way Dependabot will update them as available and we
# stay in a known state.
FROM hadolint/hadolint:v2.14.0-debian AS hadolint-src
FROM rhysd/actionlint:1.7.8 AS actionlint-src
FROM mvdan/shfmt:v3.12.0 AS shfmt-src
FROM mikefarah/yq:4.50.1 AS yq-src
FROM ghcr.io/zizmorcore/zizmor:1.21.0 AS zizmor-src
FROM ghcr.io/jqlang/jq:1.8.1 AS jq-src
# ----------------------------------
# End General Tool Images
# ----------------------------------

# Just setting this one up for re-use so it only needs to be updated in one place.
# Useful in case we add new stages so the same base is used everywhere.
FROM ubuntu:noble-20260113 AS base-runtime

# ---------- Browser installation stage ----------
# Use node-src as the base since it has npm/npx available
# without spending extra time to install it to the base-runtime.
FROM node-src AS browser-installer
ARG TARGETARCH
ARG PUPPETEER_CACHE_DIR=/browsers
ARG BROWSER_CACHE=/browser-cache

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=type=cache,target=${BROWSER_CACHE},id=puppeteer-browsers-${TARGETARCH},sharing=shared \
  <<EOF
set -eux
# Install to cache directory first
CHROME_PATH=$(npx -y @puppeteer/browsers install chrome@stable --path "${BROWSER_CACHE}" | tail -n 1 | cut -d' ' -f2)
CHROMEDRIVER_PATH=$(npx -y @puppeteer/browsers install chromedriver@stable --path "${BROWSER_CACHE}" | tail -n 1 | cut -d' ' -f2)
# Copy from cache to permanent location
mkdir -p "${PUPPETEER_CACHE_DIR}"
cp -r "${BROWSER_CACHE}"/* "${PUPPETEER_CACHE_DIR}"/
# Save paths (adjust to use permanent location)
echo "${CHROME_PATH/${BROWSER_CACHE}/${PUPPETEER_CACHE_DIR}}" > /chrome_path.txt
echo "${CHROMEDRIVER_PATH/${BROWSER_CACHE}/${PUPPETEER_CACHE_DIR}}" > /chromedriver_path.txt
EOF

# ---------- Final dev runtime ----------
FROM base-runtime AS dev-runtime
ARG TARGETARCH
ARG NODE_VERSION
ARG DEBIAN_FRONTEND=noninteractive
ARG APT_LISTCHANGES_FRONTEND=none
ARG UCF_FORCE_CONFFNEW=1

LABEL org.opencontainers.image.title="Development Container" \
      org.opencontainers.image.description="Development environment with Node.js, Java, Gradle, Python, and various dev tools installed." \
      org.opencontainers.image.url="https://github.com/garbee/docker-containers" \
      org.opencontainers.image.source="https://github.com/garbee/docker-containers" \
      org.opencontainers.image.documentation="https://github.com/garbee/docker-containers" \
      org.opencontainers.image.vendor="Garbee" \
      org.opencontainers.image.licenses="CC-PDM-1.0" \
      org.opencontainers.image.authors="Garbee" \
      me.garbee.environments="development,ci"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PATH="/usr/local/lib/node_modules/bin:\
/opt/venv/bin:\
/opt/gradle/bin:\
/opt/java/openjdk/bin:\
/home/ubuntu/.local/bin:\
/usr/local/bin:\
/usr/bin:${PATH}" \
  JAVA_HOME=/opt/java/openjdk \
  GRADLE_HOME=/opt/gradle \
  NODE_ENV=development \
  NPM_CONFIG_FUND=false \
  NPM_CONFIG_AUDIT=false \
  FZF_DEFAULT_OPTS="--height=40% --reverse --border" \
  PUPPETEER_CACHE_DIR=/browsers \
  PUPPETEER_SKIP_DOWNLOAD=true \
  TZ=UTC

RUN <<EOF
set -euxo pipefail
:"${PUPPETEER_CACHE_DIR:?PUPPETEER_CACHE_DIR must be set}"

groupadd -r node
usermod -aG node ubuntu
usermod -aG staff ubuntu
mkdir -p /usr/local/lib/node_modules
chown -R root:node /usr/local/lib/node_modules /usr/local/bin
chmod -R 775 /usr/local/lib/node_modules /usr/local/bin
mkdir -p "${PUPPETEER_CACHE_DIR}"
chown -R root:staff "${PUPPETEER_CACHE_DIR}"
chmod -R 775 "${PUPPETEER_CACHE_DIR}"
mkdir -p /etc/apt/keyrings
chmod 755 /etc/apt/keyrings
mkdir -p /etc/apt/sources.list.d
chmod 755 /etc/apt/sources.list.d
EOF

# Bring in toolchains/artifacts (optimized with --link)
COPY --link --from=hadolint-src   /bin/hadolint /usr/local/bin/
# Actionlint also has shellcheck in its bin
COPY --link --from=actionlint-src  /usr/local/bin/ /usr/local/bin/
COPY --link --from=jq-src          /jq     /usr/local/bin/jq
COPY --link --from=yq-src          /usr/bin/yq     /usr/local/bin/yq
COPY --link --from=zizmor-src      /usr/bin/zizmor /usr/local/bin/zizmor
COPY --link --from=shfmt-src       /bin/              /usr/local/bin/

# Symlink-dependent toolchains (cannot use --link)
COPY --from=node-src /usr/local/ /usr/local/
COPY --from=node-src /opt /opt
COPY --from=jdk-src $JAVA_HOME $JAVA_HOME
COPY --from=gradle-src /opt/gradle ${GRADLE_HOME}
COPY --from=gradle-src /usr/bin/gradle /usr/bin/gradle

# Copy browsers from browser-installer stage
COPY --link --from=browser-installer ${PUPPETEER_CACHE_DIR} ${PUPPETEER_CACHE_DIR}
COPY --from=browser-installer /chrome_path.txt /chrome_path.txt
COPY --from=browser-installer /chromedriver_path.txt /chromedriver_path.txt

ADD --chmod=0044 https://cli.github.com/packages/githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg

RUN --mount=type=cache,target=/var/cache/apt,id=apt-archives,sharing=shared \
  --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists,sharing=locked \
  --mount=type=cache,target=/root/.npm,id=npm-cache-${TARGETARCH}-${NODE_VERSION},sharing=shared \
  --mount=type=cache,target=/root/.cache/pip,id=pip-cache-${TARGETARCH},sharing=shared \
  <<EOF
set -euxo pipefail
apt-get update
apt-get install -y --no-install-recommends software-properties-common
add-apt-repository ppa:git-core/ppa -y
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install -y --no-install-recommends \
  python3.12 python3.12-venv python3.12-dev \
  python3-pip \
  libpulse0 \
  fonts-noto fonts-noto-color-emoji \
  ca-certificates \
  fonts-liberation \
  libasound2t64 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libcairo2 \
  libcups2 \
  libdbus-1-3 \
  libexpat1 \
  libfontconfig1 \
  libgbm1 \
  libglib2.0-0 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  libx11-6 \
  libx11-xcb1 \
  libxcb1 \
  libxcomposite1 \
  libxcursor1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxi6 \
  libxrandr2 \
  libxrender1 \
  libxss1 \
  libxtst6 \
  wget \
  xdg-utils \
  bash-completion fzf ripgrep bat direnv eza git-delta \
  curl lsb-release unzip \
  openssh-client gnupg gnupg2 git gh \
  sudo gosu \
  xvfb
rm -rf /var/lib/apt/lists/*

# Setup Puppeteer browser environment variables
CHROME_PATH=$(cat /chrome_path.txt)
echo "export CHROME_BIN=${CHROME_PATH}" >> /etc/environment
CHROMEDRIVER_PATH=$(cat /chromedriver_path.txt)
echo "export CHROMEDRIVER_BIN=${CHROMEDRIVER_PATH}" >> /etc/environment
rm /chrome_path.txt /chromedriver_path.txt

# Setup sudo access
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu

# Install latest npm version globally
npm install -g npm@latest

## Configure npm and yarn
npm config set -g '@deque:registry=https://agora.dequecloud.com/artifactory/api/npm/dequelabs/'
## Disable funding messages and automatic audits
npm config set -g fund false
npm config set -g audit false
## Reduce output to keep CI logs clean
npm config set -g progress false
## Prefer the offline modules when possible to speed up installs
## Particularly useful in CI environments with caching enabled
npm config set -g prefer-offline true
## Help network or registry issues by massaging the network config
npm config set -g fetch-retries 6
npm config set -g fetch-retry-mintimeout 20000
npm config set -g fetch-retry-maxtimeout 120000

## Help the network with yarn too as best we can.
cat > /etc/.yarnrc <<EOYARNRC
prefer-offline true
network-timeout 300000
network-concurrency 8
EOYARNRC

# Setup Python virtual environment for main user
python3.12 -m venv /opt/venv
chown -R root:ubuntu /opt/venv
chmod -R 775 /opt/venv
/opt/venv/bin/pip install --no-cache-dir pip-licenses autopep8 pylint
EOF

WORKDIR /workspaces

CMD [ "bash" ]
