# syntax=docker/dockerfile:1.9
FROM python:3.11-slim

# Set up the working directory
WORKDIR /app

# Install necessary system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy application files (must be done before installing dependencies)
COPY ./server/pyproject.toml ./server/README.md ./server/uv.lock ./
COPY ./server/graph_service ./graph_service

# Install dependencies using standard pip (including uvicorn)
# NOTE: If uv.lock is complex, this step might require converting it to requirements.txt first.
RUN pip install uvicorn gunicorn && \
    pip install --no-cache-dir -r ./server/uv.lock

# 🛑 NO USER INSTRUCTION - CONTAINER RUNS AS ROOT 🛑
ENV PYTHONUNBUFFERED=1

# Set port
ENV PORT=8000
EXPOSE $PORT

# ❗ FINAL COMMAND: Execute the uvicorn module using the native Python interpreter ❗
# This is the last possible method to bypass environment executable restrictions.
CMD ["python", "-m", "uvicorn", "graph_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
