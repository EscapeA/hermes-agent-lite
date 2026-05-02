# ============================================================
# Hermes Agent Lite — 极简版
# 仅：长期记忆 + 消息平台(Telegram + Yuanbao) + 图片视觉 + 终端工具
# 无浏览器 / 无 TUI / 无 Web Dashboard / 无 Playwright / 无 Node.js
# ============================================================
FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie AS uv_source
FROM tianon/gosu:1.19-trixie AS gosu_source
FROM debian:13.4

ENV PYTHONUNBUFFERED=1
ENV HERMES_HOME=/opt/data
ENV HERMES_DISABLE_BROWSER=true

# ── 最小系统依赖（无 nodejs/npm/playwright/ffmpeg/docker） ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    python3-dev \
    gcc \
    libffi-dev \
    curl \
    ripgrep \
    procps \
    git \
    openssh-client \
    tini \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 --from=gosu_source /gosu /usr/local/bin/
COPY --chmod=0755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

WORKDIR /opt/hermes

# ── 依赖层缓存（仅复制清单文件）──
COPY pyproject.toml uv.lock ./
RUN uv venv

# ── 源码（.dockerignore 已排除所有不需要的目录）──
COPY . .

# ── 仅安装核心 + Telegram + Yuanbao（跳过所有重型 extras）──
# 核心：openai, anthropic, httpx, rich, pydantic, croniter, edge-tts 等
# Telegram：消息平台
# Yuanbao：消息平台（纯 Python，httpx 已在核心依赖中）
# 不装：voice(whisper), rl(atropos), web(dashboard), honcho, matrix,
#       modal, daytona, vercel, tts-premium, dev, bedrock, mistral, google
RUN uv pip install --no-cache-dir -e "." && \
    uv pip install --no-cache-dir "python-telegram-bot[webhooks]>=22.6,<23"

# ── 创建运行用户 + 权限 ──
RUN useradd -u 10000 -m -d /opt/data hermes && \
    chmod -R a+rX /opt/hermes && \
    chown -R hermes:hermes /opt/hermes

VOLUME ["/opt/data"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/opt/hermes/docker/entrypoint.sh"]
