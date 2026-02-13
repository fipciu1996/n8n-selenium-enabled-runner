ARG PYTHON_VERSION=3.13

# ==============================================================================
# STAGE 1: Python runner build (@n8n/task-runner-python) with uv
# Produces a relocatable venv tied to the python version used
# ==============================================================================
FROM python:${PYTHON_VERSION}-alpine AS python-runner-builder
ARG TARGETPLATFORM
ARG UV_VERSION=0.8.14

RUN set -e; \
  case "$TARGETPLATFORM" in \
    "linux/amd64") UV_ARCH="x86_64-unknown-linux-musl" ;; \
    "linux/arm64") UV_ARCH="aarch64-unknown-linux-musl" ;; \
    *) echo "Unsupported platform: $TARGETPLATFORM" >&2; exit 1 ;; \
  esac; \
  mkdir -p /tmp/uv && cd /tmp/uv; \
  wget -q "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz"; \
  wget -q "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz.sha256"; \
  sha256sum -c "uv-${UV_ARCH}.tar.gz.sha256"; \
  tar -xzf "uv-${UV_ARCH}.tar.gz"; \
  install -m 0755 "uv-${UV_ARCH}/uv" /usr/local/bin/uv; \
  cd / && rm -rf /tmp/uv

WORKDIR /app/task-runner-python

COPY sources/n8n/packages/@n8n/task-runner-python/pyproject.toml \
     sources/n8n/packages/@n8n/task-runner-python/uv.lock** \
     sources/n8n/packages/@n8n/task-runner-python/.python-version** \
     ./
COPY requirements.txt /workdir/requirements.txt

RUN uv venv
RUN uv sync \
      --frozen \
      --no-editable \
      --no-install-project \
      --no-dev \
      --all-extras

COPY sources/n8n/packages/@n8n/task-runner-python/README.md ./README.md
COPY sources/n8n/packages/@n8n/task-runner-python/src ./src
RUN uv sync \
      --frozen \
      --no-dev \
      --all-extras \
      --no-editable

# Install extra Python dependencies for Selenium/web scraping into the runner venv
RUN uv pip install -r /workdir/requirements.txt

# Install the python runner package itself into site packages. We can remove the src directory then
RUN uv pip install . && rm -rf /app/task-runner-python/src

# ==============================================================================
# STAGE 2: Task Runner Launcher download
# ==============================================================================
FROM alpine:3.22.1 AS launcher-downloader
ARG TARGETPLATFORM
ARG LAUNCHER_VERSION=1.4.2

RUN set -e; \
    case "$TARGETPLATFORM" in \
        "linux/amd64") ARCH_NAME="amd64" ;; \
        "linux/arm64") ARCH_NAME="arm64" ;; \
        *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac; \
    mkdir /launcher-temp && cd /launcher-temp; \
    wget -q "https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz"; \
    wget -q "https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz.sha256"; \
    echo "$(cat task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz.sha256) task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz" > checksum.sha256; \
    sha256sum -c checksum.sha256; \
    mkdir -p /launcher-bin; \
    tar xzf task-runner-launcher-${LAUNCHER_VERSION}-linux-${ARCH_NAME}.tar.gz -C /launcher-bin; \
    cd / && rm -rf /launcher-temp

# ==============================================================================
# STAGE 3: Runtime
# ==============================================================================
FROM python:${PYTHON_VERSION}-alpine AS runtime
ARG N8N_VERSION=snapshot
ARG N8N_RELEASE_TYPE=dev

ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE} \
    SHELL=/bin/sh

# Bring `uv` over from python-runner-builder, to make the image easier to extend
COPY --from=python-runner-builder /usr/local/bin/uv /usr/local/bin/uv

# libc6-compat is required by task-runner-launcher
# Keep apk-tools installed for troubleshooting and later extensions.
# Add Chromium and dependencies for Selenium-based web scraping.
RUN apk add --no-cache \
    ca-certificates \
    tini \
    libc6-compat \
    chromium \
    chromium-chromedriver \
    nss \
    freetype \
    harfbuzz \
    ttf-freefont \
    libxcb \
    libx11 \
    libxcomposite \
    libxdamage \
    libxrandr \
    libxkbcommon \
    libdrm \
    mesa-gbm \
    alsa-lib \
    cups-libs \
    pango \
    cairo

RUN addgroup -g 1000 -S runner \
 && adduser  -u 1000 -S -G runner -h /home/runner -D runner

WORKDIR /home/runner

COPY --from=python-runner-builder --chown=root:root /app/task-runner-python /opt/runners/task-runner-python
COPY --from=launcher-downloader /launcher-bin/* /usr/local/bin/
COPY --chown=root:root n8n-task-runners.json /etc/n8n-task-runners.json

USER runner

EXPOSE 5680/tcp
ENTRYPOINT ["tini", "--", "/usr/local/bin/task-runner-launcher"]
CMD ["python"]

LABEL org.opencontainers.image.title="n8n task runners" \
      org.opencontainers.image.description="Sidecar image providing n8n task runners for Python code execution" \
      org.opencontainers.image.source="https://github.com/n8n-io/n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version="${N8N_VERSION}"
