FROM node:18-bookworm

RUN apt-get update && apt-get install -y curl python3 make g++ && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./codebase .

# Install dependencies and build
RUN npm install --legacy-peer-deps
RUN npm run tsc || true

# Create data directory
RUN mkdir -p /app/data

EXPOSE 3000

# Initialize the SQLite database schema, then start
CMD ["sh", "-c", "npx saltcorn add-schema -f 2>/dev/null; npx saltcorn serve --port 3000"]
