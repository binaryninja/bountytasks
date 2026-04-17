FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    pkg-config \
    libcairo2-dev \
    libgirepository1.0-dev \
    gir1.2-glib-2.0 \
    gir1.2-gtk-3.0 \
    gir1.2-gexiv2-0.10 \
    gettext \
    intltool \
    libxml2-dev \
    libicu-dev \
    gcc \
    g++ \
    locales \
    xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV GDK_BACKEND=x11
ENV DISPLAY=:99

WORKDIR /app
COPY ./codebase .
COPY ./docker-entrypoint.sh /usr/local/bin/gramps-task-entrypoint.sh

# Install gunicorn and waitress explicitly, then the app
RUN pip install --no-cache-dir gunicorn waitress
RUN pip install --no-cache-dir -e .

# Create required directories
RUN mkdir -p /app/config /app/static /app/db /app/db/grampsdb /app/media /app/indexdir /app/users \
    /app/thumbnail_cache /app/cache/reports /app/cache/export /app/export_cache \
    /app/cache/request_cache /app/cache/persistent_cache /app/tmp /app/persist
RUN touch /app/config/config.cfg /app/static/index.html \
    && chmod +x /usr/local/bin/gramps-task-entrypoint.sh

ENV GRAMPS_API_CONFIG=/app/config/config.cfg
ENV GRAMPSWEB_TREE=BountyTest
ENV GRAMPSWEB_SECRET_KEY=bounty-test-secret
ENV GRAMPSWEB_USER_DB_URI=sqlite:////app/users/users.sqlite
ENV GRAMPSWEB_MEDIA_BASE_DIR=/app/media
ENV GRAMPSWEB_SEARCH_INDEX_DB_URI=sqlite:////app/indexdir/search_index.db
ENV GRAMPSWEB_STATIC_PATH=/app/static
ENV GRAMPSWEB_THUMBNAIL_CACHE_CONFIG__CACHE_DIR=/app/thumbnail_cache
ENV GRAMPSWEB_REQUEST_CACHE_CONFIG__CACHE_DIR=/app/cache/request_cache
ENV GRAMPSWEB_PERSISTENT_CACHE_CONFIG__CACHE_DIR=/app/cache/persistent_cache
ENV GRAMPSHOME=/root
ENV GRAMPS_DATABASE_PATH=/app/db/grampsdb

# ── Benchmark-harness deployment tuning (does NOT change the CVE code) ──
# The default RATE_LIMIT_MEDIA_ARCHIVE is "1 per day", which throttles
# concurrent exploit workers in the v2 pipeline (one shot per worker per
# 24 h is unusable for fan-out). We raise it to a test-friendly level.
# Similarly the default 2 gunicorn workers + 120s timeout cause worker-
# timeout thrash when 4+ exploit agents probe the same instance
# concurrently with long-running archive-import requests. We bump both.
#
# None of these changes affect the vulnerability itself (CVE-2026-40258
# lives in gramps_webapi/api/media_importer.py path handling) — only
# the operational-limits surface of the test deployment.
ENV GRAMPSWEB_RATE_LIMIT_MEDIA_ARCHIVE="1000 per hour"

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/gramps-task-entrypoint.sh"]
CMD ["gunicorn", "-w", "6", "-b", "0.0.0.0:5000", "gramps_webapi.wsgi:app", "--timeout", "600", "--graceful-timeout", "600"]
