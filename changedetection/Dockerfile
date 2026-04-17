FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y \
    curl \
    g++ \
    gcc \
    libc-dev \
    libffi-dev \
    libjpeg-dev \
    libssl-dev \
    libxslt-dev \
    make \
    pkg-config \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./codebase .

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -e .

RUN mkdir -p /datastore

EXPOSE 5000

# Uses -h for host, -p for port, -d for datastore path
CMD ["python", "./changedetection.py", "-h", "0.0.0.0", "-p", "5000", "-d", "/datastore"]
