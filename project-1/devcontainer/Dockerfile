# hadolint global ignore=DL3008,DL3013
# syntax=docker/dockerfile:1.6

ARG NODE_VERSION=22.21.1
ARG GRADLE_VERSION=8.14.3
ARG JAVA_VERSION=21.0.9_10
ARG HADOLINT_VERSION=2.14.0
ARG ACTIONLINT_VERSION=1.7.8
ARG SHFMT_VERSION=3.12.0
ARG YQ_VERSION=4.48.1
ARG ZIZMOR_VERSION=1.16.3

FROM node:${NODE_VERSION}-bookworm-slim AS node-src
FROM gradle:${GRADLE_VERSION}-jdk21-noble AS gradle-src
FROM eclipse-temurin:${JAVA_VERSION}-jdk-noble AS jdk-src
FROM hadolint/hadolint:v${HADOLINT_VERSION}-debian AS hadolint-src
FROM garbee/github-cli:2.78.0 AS gh-cli-src
FROM rhysd/actionlint:${ACTIONLINT_VERSION} AS actionlint-src
FROM mvdan/shfmt:v${SHFMT_VERSION} AS shfmt-src
FROM mikefarah/yq:${YQ_VERSION} AS yq-src
FROM ghcr.io/zizmorcore/zizmor:${ZIZMOR_VERSION} AS zizmor-src
# Just setting this one up for re-use so it only needs to be updated in one place.
FROM ubuntu:noble-20251001 AS base-runtime

# ---------- Git from source ----------
FROM base-runtime AS git-dist
ARG GIT_VERSION=2.51.2
ARG GIT_CHECKSUM=233d7143a2d58e60755eee9b76f559ec73ea2b3c297f5b503162ace95966b4e3
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /tmp
ENV DEBIAN_FRONTEND=noninteractive \
  APT_LISTCHANGES_FRONTEND=none \
  UCF_FORCE_CONFFNEW=1 \
  TZ=UTC \
  NO_TCLTK=YesPlease \
  NO_GETTEXT=YesPlease \
  NO_SVN_TESTS=YesPlease \
  NO_GITWEB=YesPlease \
  NO_INSTALL_HARDLINKS=YesPlease \
  NO_PERL=YesPlease \
  NO_PYTHON=YesPlease \
  OPENSSL_SHA256=YesPlease \
  CFLAGS="-O2 -pipe -march=native" \
  LDFLAGS="-Wl,--as-needed" \
  TARBALL="/tmp/git-${GIT_VERSION}.tar.xz" \
  SIGNATURE="/tmp/git-${GIT_VERSION}.tar.sign"

ADD --checksum=sha256:${GIT_CHECKSUM} \
  https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz ${TARBALL}
ADD https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.sign ${SIGNATURE}

RUN --mount=type=cache,target=/var/cache/apt,id=apt-archives,sharing=shared \
  --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists,sharing=locked \
  set -eux; \
  apt-get update && apt-get install -y --no-install-recommends \
  autoconf \
  build-essential \
  ca-certificates \
  curl \
  dirmngr \
  gettext \
  git \
  gnupg \
  libcurl4-gnutls-dev \
  libexpat1-dev \
  libssl-dev \
  software-properties-common \
  unzip \
  xz-utils \
  zlib1g-dev; \
  rm -rf /var/lib/apt/lists/*; \
  # Import Git maintainer keys and verify signature
  GNUPGHOME="$(mktemp -d)"; \
  export GNUPGHOME; \
  # Import both primary key and signing subkey for the git maintainer
  # To find current key IDs: download a recent .tar.sign file and run:
  # gpg --verify git-X.Y.Z.tar.sign git-X.Y.Z.tar.xz
  # The error will show "using RSA key KEYID" - use that KEYID below
  # Get both the primary and subkey to import.
  gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
  96E07AF25771955980DAD10020D04E5A713660A7 \
  E1F036B1FEE7221FC778ECEFB0B5E88696AFE6CB; \
  # Verify signature - note: signature is for .tar not .tar.xz
  gpg --batch --trust-model tofu --verify "${SIGNATURE}" <(xz -dc "${TARBALL}"); \
  rm -rf "${GNUPGHOME}" "${SIGNATURE}"; \
  # Extract source directly into current directory
  tar -xJf "${TARBALL}" --strip-components=1; \
  rm "${TARBALL}"; \
  # Build Git
  make -j"$(nproc)" configure; \
  ./configure --prefix=/opt/git --disable-nls; \
  make all -j"$(nproc)";\
  make install;

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
ARG IMAGE_VERSION=0.0.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV PATH="/home/ubuntu/.npm-global/bin:\
/home/ubuntu/.local/bin:\
/opt/gradle/bin:\
/opt/java/openjdk/bin:\
/usr/local/bin:\
/usr/bin:${PATH}" \
  JAVA_HOME=/opt/java/openjdk \
  GRADLE_HOME=/opt/gradle \
  NODE_ENV=development \
  NPM_CONFIG_FUND=false \
  NPM_CONFIG_AUDIT=false \
  FZF_DEFAULT_OPTS="--height=40% --reverse --border" \
  NPM_CONFIG_PREFIX=/home/ubuntu/.npm-global

# Bring in toolchains/artifacts (optimized with --link)
COPY --link --from=hadolint-src   /bin/hadolint /usr/local/bin/
COPY --link --from=gh-cli-src         /opt/     /usr/local/
# Actionlint also has shellcheck in its bin
COPY --link --from=actionlint-src  /usr/local/bin/ /usr/local/bin/
COPY --link --from=jq-dist         /opt/jq/jq     /usr/local/bin/jq
COPY --link --from=yq-src          /usr/bin/yq     /usr/local/bin/yq
COPY --link --from=zizmor-src      /usr/bin/zizmor /usr/local/bin/zizmor
COPY --link --from=shfmt-src       /bin/              /usr/local/bin/

# Symlink-dependent toolchains (cannot use --link)
COPY --from=node-src /usr/local/ /usr/local/
COPY --from=node-src /opt /opt
COPY --from=git-dist        /opt/git                       /usr/local/
COPY --from=jdk-src $JAVA_HOME $JAVA_HOME
COPY --from=gradle-src /opt/gradle ${GRADLE_HOME}
COPY --from=gradle-src /usr/bin/gradle /usr/bin/gradle

RUN --mount=type=cache,target=/var/cache/apt,id=apt-archives,sharing=shared \
  --mount=type=cache,target=/var/lib/apt/lists,id=apt-lists,sharing=locked \
  set -eux; \
  DEBIAN_FRONTEND=noninteractive \
  APT_LISTCHANGES_FRONTEND=none \
  UCF_FORCE_CONFFNEW=1 \
  TZ=UTC \
  apt-get update; \
  apt-get install -y --no-install-recommends software-properties-common \
  # Python installations
  python3.12 python3.12-venv python3.12-dev \
  python3-pip \
  # For FFMPEG
  libpulse0 \
  # Fonts Noto (about 56MB)
  fonts-noto fonts-noto-color-emoji \
  # Developer Experience Additions (about 68MB)
  bash-completion fzf ripgrep bat direnv eza git-delta neovim \
  curl lsb-release unzip \
  # Core development needs
  openssh-client gnupg gnupg2 \
  # User privilege management
  sudo gosu; \
  rm -rf /var/lib/apt/lists/*; \
  # Give ubuntu user password-less sudo access
  echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu; \
  chmod 0440 /etc/sudoers.d/ubuntu; \
  # Install globally used python tools
  gosu ubuntu python3.12 -m pip install --no-cache-dir --user --break-system-packages autopep8 pylint pip-licenses; \
  gosu ubuntu mkdir -p /home/ubuntu/.npm-global; \
  gosu ubuntu mkdir -p /home/ubuntu/.claude;

ADD --chown=1000:1000 --chmod=744 https://raw.githubusercontent.com/git/git/refs/tags/v2.51.0/contrib/completion/git-prompt.sh /home/ubuntu/.bashrc.d/01-git-prompt.sh

USER ubuntu

RUN npx -y playwright@latest install chromium --with-deps

CMD [ "sleep", "infinity" ]
