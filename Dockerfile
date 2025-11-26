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
    && rm -rf /var/lib/apt/lists/*

# 1. Create the non-root user early
RUN groupadd -r app && useradd -r -d /app -g app app

# Set up the server application first
WORKDIR /app

# 2. Create local directory for user-specific executable install
RUN mkdir -p /app/local
# 3. Ensure the app user owns the installation path
RUN chown -R app:app /app/local

# Temporarily switch to the app user to install uv into their owned path
USER app

# ❗ CRITICAL FIX: Install uv into a path owned by the 'app' user ❗
# uv is installed into /app/local/bin/uv
RUN pip install --prefix=/app/local uv

# Switch back to root to continue building (if needed)
USER root

# Configure uv for runtime
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Copy application files (must be done by root or have permissions changed)
COPY ./server/pyproject.toml ./server/README.md ./server/uv.lock ./
COPY ./server/graph_service ./graph_service

# Install server dependencies (We must explicitly use the full path to uv here)
ARG INSTALL_FALKORDB=false
RUN --mount=type=cache,target=/root/.cache/uv \
    /app/local/bin/uv sync --frozen --no-dev && \
    if [ -n "$GRAPHITI_VERSION" ]; then \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            /app/local/bin/uv pip install --system --upgrade "graphiti-core[falkordb]==$GRAPHITI_VERSION"; \
        else \
            /app/local/bin/uv pip install --system --upgrade "graphiti-core==$GRAPHITI_VERSION"; \
        fi; \
    else \
        if [ "$INSTALL_FALKORDB" = "true" ]; then \
            /app/local/bin/uv pip install --system --upgrade "graphiti-core[falkordb]"; \
        else \
            /app/local/bin/uv pip install --system --upgrade graphiti-core; \
        fi; \
    fi

# Change ownership of application code to app user
RUN chown -R app:app /app

# Set environment variables (Add the new executable path)
ENV PYTHONUNBUFFERED=1 \
    PATH="/app/local/bin:/app/.venv/bin:$PATH"

# Switch to non-root user
USER app

# Set port
ENV PORT=8000
EXPOSE $PORT

# ❗ FINAL COMMAND: Using the path guaranteed by the user-specific install ❗
CMD ["/app/local/bin/uv", "run", "uvicorn", "graph_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
