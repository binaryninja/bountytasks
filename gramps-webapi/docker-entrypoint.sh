#!/bin/sh
set -eu

GRAMPS_DATABASE_PATH="${GRAMPS_DATABASE_PATH:-/app/db/grampsdb}"
GRAMPSWEB_TREE="${GRAMPSWEB_TREE:-BountyTest}"
USER_DB_PATH="/app/users/users.sqlite"

export GRAMPS_DATABASE_PATH
export GRAMPSWEB_TREE
export USER_DB_PATH

SERVER_DISPLAY="${DISPLAY:-:99}"
unset DISPLAY

mkdir -p \
    "$GRAMPS_DATABASE_PATH" \
    /app/config \
    /app/static \
    /app/media \
    /app/indexdir \
    /app/users \
    /app/export_cache \
    /app/cache/request_cache \
    /app/cache/persistent_cache \
    /app/thumbnail_cache

if ! find "$GRAMPS_DATABASE_PATH" -mindepth 2 -maxdepth 2 -name sqlite.db -print -quit | grep -q .; then
    echo "Initializing example Gramps tree at $GRAMPS_DATABASE_PATH"
    python3 - <<'PY'
import gzip
import os
import shutil
import tempfile
from pathlib import Path

from gramps.cli.clidbman import CLIDbManager
from gramps.cli.grampscli import CLIManager
from gramps.gen.config import set as setconfig
from gramps.gen.dbstate import DbState
from gramps.gen.user import User
from gramps.gen.utils.resourcepath import ResourcePath

dbdir = os.environ["GRAMPS_DATABASE_PATH"]
tree_name = os.environ["GRAMPSWEB_TREE"]
os.makedirs(dbdir, exist_ok=True)
setconfig("database.path", dbdir)

resources = ResourcePath()
os.environ["GRAMPS_RESOURCES"] = str(Path(resources.data_dir).parent)
example_dir = os.path.join(resources.doc_dir, "example", "gramps")
example_path = os.path.join(example_dir, "example.gramps")
tmpdir = None

if not os.path.isfile(example_path):
    gz_path = os.path.join(example_dir, "example.gramps.gz")
    tmpdir = tempfile.mkdtemp(prefix="gramps-example-")
    example_path = os.path.join(tmpdir, "example.gramps")
    with gzip.open(gz_path, "rb") as src, open(example_path, "wb") as dst:
        shutil.copyfileobj(src, dst)

try:
    dbstate = DbState()
    dbman = CLIDbManager(dbstate)
    smgr = CLIManager(dbstate, True, User())
    smgr.do_reg_plugins(dbstate, uistate=None)
    path, import_name = dbman.import_new_db(example_path, User())
    if import_name != tree_name:
        dbman.rename_database(os.path.join(path, "name.txt"), tree_name)
finally:
    if tmpdir is not None:
        shutil.rmtree(tmpdir)
PY
fi

echo "Migrating Gramps Web user database"
python3 -m gramps_webapi user migrate

if ! python3 - <<'PY'
import os
import sqlite3
import sys

db_path = os.environ["USER_DB_PATH"]
if not os.path.exists(db_path):
    sys.exit(1)

conn = sqlite3.connect(db_path)
try:
    row = conn.execute("SELECT 1 FROM users WHERE name = ?", ("owner",)).fetchone()
finally:
    conn.close()

sys.exit(0 if row else 1)
PY
then
    echo "Seeding owner account"
    python3 -m gramps_webapi user add owner owner --fullname Owner --role 4
fi

export DISPLAY="$SERVER_DISPLAY"
Xvfb "$DISPLAY" -screen 0 1024x768x24 >/tmp/xvfb.log 2>&1 &
exec "$@"
