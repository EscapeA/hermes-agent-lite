FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie AS uv_source
FROM tianon/gosu:1.19-trixie AS gosu_source
FROM debian:13.4

ENV PYTHONUNBUFFERED=1
ENV HERMES_HOME=/opt/data
ENV DEBIAN_FRONTEND=noninteractive
ENV HERMES_DISABLE_BROWSER=true

# 仅 x86 必需系统依赖（无浏览器/无前端/无冗余）
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    python3-dev \
    gcc \
    libffi-dev \
    ripgrep \
    procps \
    git \
    openssh-client \
    tini \
    && rm -rf /var/lib/apt/lists/*

# 复制工具
COPY --chmod=755 --from=gosu_source /gosu /usr/local/bin/
COPY --chmod=755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

WORKDIR /opt/hermes

# 先复制依赖清单
COPY pyproject.toml uv.lock ./

# 移除浏览器/playwright依赖（避免安装不必要的包）
RUN sed -i '/playwright/d' pyproject.toml && \
    sed -i '/browser/d' pyproject.toml

# 先创建虚拟环境，后续再以 editable 模式安装完整项目
RUN uv venv

# 现在复制所有源码（关键修复：先复制再安装，确保模块路径正确）
COPY . .

# 删除非必要目录（web/ui-tui/node_modules），不影响核心代码
RUN rm -rf web ui-tui node_modules

# 以 editable 模式安装项目（此时 hermes_cli/ 已经存在）
RUN uv pip install --no-cache-dir -e ".[all]"

# 创建运行用户
RUN useradd -u 10000 -m -d /opt/data hermes && \
    chown -R hermes:hermes /opt/hermes

USER hermes
VOLUME [ "/opt/data" ]

# 安全启动入口
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/opt/hermes/docker/entrypoint.sh"]
