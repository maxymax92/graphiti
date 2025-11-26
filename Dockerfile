# syntax=docker/dockerfile:1.9
FROM python:3.11-slim

# Inherit build arguments for labels
ARG GRAPHITI_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI image annotations
LABEL org.opencontainers.image.title="Graphiti FastAPI Server"
LABEL org.opencontainers.image.description="FastAPI server for Graphiti temporal knowledge graphs"
LABEL org.opencontainers.image.version="${GRAPHITI_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Zep AI"
LABEL org.opencontainers.image.source="https://github.com/getzep/graphiti"
LABEL org.opencontainers.image.documentation="https://github.com/getzep/graphiti/tree/main/server"
LABEL io.graphiti.core.version="${GRAPHITI_VERSION}"

# Install uv using the installer script
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh

# The uv installer places uv in /root/.local/bin
ENV PATH="/root/.local/bin:$PATH"

# FIX 1: Move uv to a global PATH
RUN mv /root/.local/bin/uv /usr/local/bin/uv

# FIX 2: Explicitly ensure the uv binary is executable for everyone.
RUN chmod +x /usr/local/bin/uv

# Create non-root user and give it ownership of the uv binary
RUN groupadd -r app && useradd -r -d /app -g app app \
    && chown app:app /usr/local/bin/uv

# Configure uv for runtime
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Set up the server application first
WORKDIR /app
COPY ./server/pyproject.toml ./server/README.md ./server/uv.lock ./
COPY ./server/graph_service ./graph_service

# Install server dependencies 
ARG INSTALL_FALKORDB=false
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev && \
    if [ -n "$GRAPHITI_VERSION" ]; then \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            uv pip install --system --upgrade "graphiti-core[falkordb]==$GRAPHITI_VERSION"; \
        else \
            uv pip install --system --upgrade "graphiti-core==$GRAPHITI_VERSION"; \
        fi; \
    else \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            uv pip install --system --upgrade "graphiti-core[falkordb]"; \
        else \
            uv pip install --system --upgrade graphiti-core; \
        fi; \
    fi

# Change ownership of application code to app user
RUN chown -R app:app /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

# Switch to non-root user
USER app

# Set port
ENV PORT=8000
EXPOSE $PORT

# ❗ CRITICAL FIX: Changed to shell form (no square brackets) to resolve runtime exec permission issues ❗
CMD /usr/local/bin/uv run uvicorn graph_service.main:app --host 0.0.0.0 --port 8000
