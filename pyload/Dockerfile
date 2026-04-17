FROM python:3.11-slim

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./codebase .

RUN pip install --no-cache-dir -e .

# Create data and download directories
RUN mkdir -p /app/data/settings /app/data/data /app/downloads

# Pre-generate config so webui binds to 0.0.0.0 (default is localhost)
RUN pyload --userdir /app/data --storagedir /app/downloads --quit 2>/dev/null || true
RUN sed -i 's/ip host : "IP address" = localhost/ip host : "IP address" = 0.0.0.0/' \
    /app/data/settings/pyload.cfg 2>/dev/null || \
    echo -e 'version: 2\n\nwebui - "Web Interface":\n\tip host : "IP address" = 0.0.0.0\n\tint port : "Port" = 8000\n\tbool enabled : "Activated" = True\n\tbool use_ssl : "Use HTTPS" = False' \
    > /app/data/settings/pyload.cfg

EXPOSE 8000

CMD ["pyload", "--userdir", "/app/data", "--storagedir", "/app/downloads"]
