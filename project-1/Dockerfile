# hadolint global ignore=DL3008,DL3013
# syntax=docker/dockerfile:1.6

ARG IMAGE_VERSION=0
ARG TARGETARCH
ARG NODE_VERSION=22.21.1
ARG GRADLE_VERSION=8.14.3
ARG JAVA_VERSION=21.0.9_10
ARG HADOLINT_VERSION=2.14.0
ARG ACTIONLINT_VERSION=1.7.8
ARG SHFMT_VERSION=3.12.0
ARG YQ_VERSION=4.48.1
ARG ZIZMOR_VERSION=1.16.3
ARG GIT_VERSION=2.51.2

FROM node:${NODE_VERSION}-bookworm-slim AS node-src
FROM gradle:${GRADLE_VERSION}-jdk21-noble AS gradle-src
FROM eclipse-temurin:${JAVA_VERSION}-jdk-noble AS jdk-src
FROM hadolint/hadolint:v${HADOLINT_VERSION}-debian AS hadolint-src
FROM rhysd/actionlint:${ACTIONLINT_VERSION} AS actionlint-src
FROM mvdan/shfmt:v${SHFMT_VERSION} AS shfmt-src
FROM mikefarah/yq:${YQ_VERSION} AS yq-src
FROM ghcr.io/zizmorcore/zizmor:${ZIZMOR_VERSION} AS zizmor-src
# Just setting this one up for re-use so it only needs to be updated in one place.
FROM ubuntu:noble-20251001 AS base-runtime

# ---------- JQ ----------
FROM busybox:1.37.0-glibc AS jq-dist
ARG JQ_VERSION=1.8.1
ARG JQ_X64_CHECKSUM=020468de7539ce70ef1bceaf7cde2e8c4f2ca6c3afb84642aabc5c97d9fc2a0d
ARG JQ_ARM64_CHECKSUM=6bc62f25981328edd3cfcfe6fe51b073f2d7e7710d7ef7fcdac28d4e384fc3d4
ARG JQ_CHECKSUMS_CHECKSUM=43580cdaf04c3ac63b9baa7fe68f28c79c5e30c3cc4fc594f87daf520626bbfa
ARG TARGETARCH
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
WORKDIR /tmp

ADD --checksum=sha256:${JQ_X64_CHECKSUM} \
  https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /tmp/jq-linux64
ADD --checksum=sha256:${JQ_ARM64_CHECKSUM} \
  https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-arm64 /tmp/jq-linux-arm64
ADD --checksum=sha256:${JQ_CHECKSUMS_CHECKSUM} \
  https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/sha256sum.txt /tmp/sha256sum.txt

RUN set -eux; \
  case "${TARGETARCH:-amd64}" in \
  amd64) JQ_FILE="jq-linux64" ;; \
  arm64) JQ_FILE="jq-linux-arm64" ;; \
  *) echo "Unsupported architecture: ${TARGETARCH}. Only amd64 and arm64 are supported." >&2; exit 1 ;; \
  esac; \
  # Verify only the selected asset using the checksums file
  grep -E "[[:space:]]${JQ_FILE}\$" sha256sum.txt | sha256sum -c -; \
  # Stage binary
  install -Dm0755 "${JQ_FILE}" /opt/jq/jq; \
  # Remove unneeded files from final image
  rm -rf /tmp/*;

# ---------- Final dev runtime ----------
FROM base-runtime AS dev-runtime
ARG IMAGE_VERSION
ARG TARGETARCH
ARG GIT_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PATH="/usr/local/lib/node_modules/bin:\
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
  PUPPETEER_SKIP_DOWNLOAD=true

RUN groupadd -r node && \
    usermod -aG node ubuntu && \
    usermod -aG staff ubuntu && \
    mkdir -p /usr/local/lib/node_modules && \
    chown -R root:node /usr/local/lib/node_modules /usr/local/bin && \
    chmod -R 775 /usr/local/lib/node_modules /usr/local/bin && \
    mkdir -p "${PUPPETEER_CACHE_DIR}" && \
    chown -R root:staff "${PUPPETEER_CACHE_DIR}" && \
    chmod -R 775 "${PUPPETEER_CACHE_DIR}"

# Bring in toolchains/artifacts (optimized with --link)
COPY --link --from=hadolint-src   /bin/hadolint /usr/local/bin/
# Actionlint also has shellcheck in its bin
COPY --link --from=actionlint-src  /usr/local/bin/ /usr/local/bin/
COPY --link --from=jq-dist         /opt/jq/jq     /usr/local/bin/jq
COPY --link --from=yq-src          /usr/bin/yq     /usr/local/bin/yq
COPY --link --from=zizmor-src      /usr/bin/zizmor /usr/local/bin/zizmor
COPY --link --from=shfmt-src       /bin/              /usr/local/bin/

# Symlink-dependent toolchains (cannot use --link)
COPY --from=node-src /usr/local/ /usr/local/
COPY --from=node-src /opt /opt
COPY --from=jdk-src $JAVA_HOME $JAVA_HOME
COPY --from=gradle-src /opt/gradle ${GRADLE_HOME}
COPY --from=gradle-src /usr/bin/gradle /usr/bin/gradle

RUN --mount=type=cache,target=/var/cache/apt,id=apt-archives,sharing=shared \
  --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists,sharing=locked \
  --mount=type=cache,target=${PUPPETEER_CACHE_DIR},id=puppeteer-browsers-${TARGETARCH},sharing=shared \
  set -eux; \
  DEBIAN_FRONTEND=noninteractive \
  APT_LISTCHANGES_FRONTEND=none \
  UCF_FORCE_CONFFNEW=1 \
  TZ=UTC \
  apt-get update \
  && apt-get install -y --no-install-recommends software-properties-common \
  && add-apt-repository ppa:git-core/ppa -y \
  && (type -p wget >/dev/null || (apt update && apt install wget -y)) \
	&& mkdir -p -m 755 /etc/apt/keyrings \
	&& out="$(mktemp)" && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt-get update \
  && apt-get install -y --no-install-recommends \
  # Python installations
  python3.12 python3.12-venv python3.12-dev \
  python3-pip python3-full python3-autopep8 pylint \
  # For FFMPEG
  libpulse0 \
  # Fonts Noto (about 56MB)
  fonts-noto fonts-noto-color-emoji \
  # Chrome/Chromium dependencies
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
  # Developer Experience Additions (about 68MB)
  bash-completion fzf ripgrep bat direnv eza git-delta neovim \
  curl lsb-release unzip \
  # Core development needs, gh is the GitHub CLI
  openssh-client gnupg gnupg2 git gh \
  # User privilege management
  sudo gosu; \
  # Always have latest stable npm
  npm install -g npm@latest; \
  # Setup Puppeteer Browsers
  CHROME_PATH=$(npx -y @puppeteer/browsers install chrome@stable --path "${PUPPETEER_CACHE_DIR}" | tail -n 1 | cut -d' ' -f2); \
  echo "export CHROME_BIN=${CHROME_PATH}" >> /etc/environment; \
  CHROMEDRIVER_PATH=$(npx -y @puppeteer/browsers install chromedriver@stable --path "${PUPPETEER_CACHE_DIR}" | tail -n 1 | cut -d' ' -f2); \
  echo "export CHROMEDRIVER_BIN=${CHROMEDRIVER_PATH}" >> /etc/environment; \
  # Clean up apt caches
  rm -rf /var/lib/apt/lists/*; \
  # Give ubuntu user password-less sudo access
  echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu; \
  chmod 0440 /etc/sudoers.d/ubuntu; \
  # Install globally used python tools that can't be installed from apt
  python3.12 -m pip config set global.break-system-packages true; \
  gosu ubuntu python3.12 -m pip config set global.break-system-packages true; \
  gosu ubuntu python3.12 -m pip install --no-cache-dir --user pip-licenses; \
  # Setup npm config
  npm config set '@deque:registry=https://agora.dequecloud.com/artifactory/api/npm/dequelabs/'; \
  gosu ubuntu npm config set '@deque:registry=https://agora.dequecloud.com/artifactory/api/npm/dequelabs/';

ADD --chown=1000:1000 --chmod=744 https://raw.githubusercontent.com/git/git/refs/tags/v${GIT_VERSION}/contrib/completion/git-prompt.sh /home/ubuntu/.bashrc.d/01-git-prompt.sh
ADD --chown=1000:1000 --chmod=744 https://raw.githubusercontent.com/git/git/refs/tags/v${GIT_VERSION}/contrib/completion/git-prompt.sh /root/.bashrc.d/01-git-prompt.sh

WORKDIR /workspaces

CMD [ "bash" ]
