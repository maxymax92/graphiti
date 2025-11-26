# syntax=docker/dockerfile:1.9
FROM python:3.11-slim

# Inherit build arguments for labels
ARG GRAPHITI_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI image annotations
LABEL org.opencontainers.image.title="Graphiti FastAPI Server"
# ... (standard labels)

# Install uv using the installer script
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ADD https://astral.sh/uv/install.sh /uv-installer.sh

# ❗ CRITICAL FIX: Install uv directly into /usr/local/bin (global access) ❗
# The installer will put 'uv' into /usr/local/bin/uv
RUN sh /uv-installer.sh --prefix /usr/local/ && rm /uv-installer.sh

# The ENV PATH line is no longer strictly necessary but kept for safety.
# The executable is now globally visible in /usr/local/bin
ENV PATH="/root/.local/bin:$PATH" 

# Create non-root user and set permissions
RUN groupadd -r app && useradd -r -d /app -g app app

# FIX: Explicitly ensure the uv binary is executable for everyone (now at /usr/local/bin/uv)
RUN chmod +x /usr/local/bin/uv

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
# ... (dependency installation logic)

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

# ❗ FINAL COMMAND: Using the guaranteed absolute path ❗
CMD ["/usr/local/bin/uv", "run", "uvicorn", "graph_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
