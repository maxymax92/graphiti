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

# Install necessary system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ❗ CRITICAL FIX: Install uv globally using pip ❗
# This ensures uv is reliably placed in /usr/local/bin and is executable.
RUN pip install uv

# Create non-root user
RUN groupadd -r app && useradd -r -d /app -g app app

# Configure uv for runtime
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Set up the server application first
WORKDIR /app
COPY ./server/pyproject.toml ./server/README.md ./server/uv.lock ./
COPY ./server/graph_service ./graph_service

# Install server dependencies (using the newly installed uv)
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

# ❗ FINAL COMMAND: Use the path guaranteed by pip install ❗
CMD ["/usr/local/bin/uv", "run", "uvicorn", "graph_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
