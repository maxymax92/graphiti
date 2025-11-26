# syntax=docker/dockerfile:1.9
FROM python:3.11-slim

# Inherit build arguments for labels
ARG GRAPHITI_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI image annotations
LABEL org.opencontainers.image.title="Graphiti FastAPI Server"
# ... (standard labels)

# Install necessary system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

ADD https://astral.sh/uv/install.sh /uv-installer.sh
# ❗ uv is installed here, and is the ONLY path that works: /root/.local/bin/uv ❗
RUN sh /uv-installer.sh && rm /uv-installer.sh

# Configure uv for runtime
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Set up the server application
WORKDIR /app

# Copy application files (running as root)
COPY ./server/pyproject.toml ./server/README.md ./server/uv.lock ./
COPY ./server/graph_service ./graph_service

# Install server dependencies (using uv from root's path)
ARG INSTALL_FALKORDB=false
RUN --mount=type=cache,target=/root/.cache/uv \
    /root/.local/bin/uv sync --frozen --no-dev && \
    if [ -n "$GRAPHITI_VERSION" ]; then \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            /root/.local/bin/uv pip install --system --upgrade "graphiti-core[falkordb]==$GRAPHITI_VERSION"; \
        else \
            /root/.local/bin/uv pip install --system --upgrade "graphiti-core==$GRAPHITI_VERSION"; \
        fi; \
    else \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            /root/.local/bin/uv pip install --system --upgrade "graphiti-core[falkordb]"; \
        else \
            /root/.local/bin/uv pip install --system --upgrade graphiti-core; \
        fi; \
    fi

# 🛑 NO USER INSTRUCTION - CONTAINER RUNS AS ROOT 🛑
ENV PYTHONUNBUFFERED=1

# Set port
ENV PORT=8000
EXPOSE $PORT

# ❗ FINAL COMMAND: Use the path guaranteed to be executable by root ❗
CMD ["/root/.local/bin/uv", "run", "uvicorn", "graph_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
