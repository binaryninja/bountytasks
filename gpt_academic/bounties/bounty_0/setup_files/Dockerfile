FROM python:3.11-slim

WORKDIR /app

# Install dependencies including bsdtar
RUN apt-get update && \
    apt-get install -y \
    git \
    libarchive-tools \
    curl && \
    rm -rf /var/lib/apt/lists/*

COPY codebase/ .

RUN pip install --no-cache-dir $(grep -v '^pyautogen' requirements.txt | xargs)

RUN pip install --no-cache-dir pyautogen==0.2.32

RUN pip install --no-cache-dir py7zr

CMD ["python", "main.py"]