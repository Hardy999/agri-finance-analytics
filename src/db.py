"""
db.py — one place that knows how to reach SQL Server.

WHY THIS FILE EXISTS
--------------------
Every later script in this project needs a database connection. The tempting
thing is to write the connection string directly into each script. Three
problems with that:

  1. The connection string contains machine-specific details (server name,
     driver version). Hard-code it in ten scripts and moving to another
     machine means editing ten scripts.
  2. If a password is ever added, it would be sitting in ten committed files.
  3. When the connection breaks, there is one place to fix it instead of ten.

So: the settings live in config.ini (which Git ignores), this file reads them,
and every other script asks this file for a connection.

HOW TO USE IT
-------------
    from db import get_engine
    engine = get_engine()

To check it works, run this file directly:

    python src/db.py
"""

import configparser
from pathlib import Path
from urllib.parse import quote_plus

from sqlalchemy import create_engine, text


# Path(__file__) is this file. .parent is src/. .parent again is the project
# root. Building the path this way means the script works no matter which
# folder you happen to be standing in when you run it — a relative path like
# "../config.ini" would break the moment you ran it from somewhere else.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = PROJECT_ROOT / "config.ini"
EXAMPLE_PATH = PROJECT_ROOT / "config.example.ini"


def load_config():
    """Read config.ini and fail loudly with a useful message if it is missing."""
    if not CONFIG_PATH.exists():
        # A clear error here saves ten minutes of confusion later. Compare this
        # to the default, which would be a FileNotFoundError naming a path with
        # no explanation of what to do about it.
        raise FileNotFoundError(
            f"config.ini not found at {CONFIG_PATH}\n"
            f"Copy {EXAMPLE_PATH.name} to config.ini and fill in your values.\n"
            f"config.ini is gitignored on purpose — it is local to this machine."
        )

    parser = configparser.ConfigParser()
    parser.read(CONFIG_PATH)
    return parser["sqlserver"]


def build_connection_url(cfg):
    """Turn the config values into the string SQLAlchemy expects.

    The odd-looking format is because SQLAlchemy hands the whole thing to
    pyodbc, which wants a semicolon-separated ODBC string. quote_plus escapes
    characters (spaces, backslashes) that would otherwise break the URL — the
    driver name 'ODBC Driver 17 for SQL Server' has spaces, and a named
    instance like 'localhost\\SQLEXPRESS' has a backslash.
    """
    parts = [
        f"DRIVER={{{cfg['driver']}}}",
        f"SERVER={cfg['server']}",
        f"DATABASE={cfg['database']}",
    ]

    if cfg.getboolean("trusted_connection", fallback=True):
        # Windows Authentication: SQL Server trusts your Windows login.
        # No password is stored anywhere, which is why this is the default.
        parts.append("Trusted_Connection=yes")

    if cfg.getboolean("trust_server_certificate", fallback=True):
        # ODBC Driver 18 encrypts by default and rejects the self-signed
        # certificate a local install uses. This says "local machine, I know
        # who I am talking to". It would NOT be acceptable against a remote
        # production server.
        parts.append("TrustServerCertificate=yes")

    odbc_str = ";".join(parts)
    return f"mssql+pyodbc:///?odbc_connect={quote_plus(odbc_str)}"


def get_engine(echo=False):
    """Return a SQLAlchemy engine for this project's database.

    An 'engine' is a connection factory, not a connection. It manages a pool
    of connections and hands one out when a query runs. This matters because
    opening a database connection is slow; reusing one is not.

    echo=True prints every SQL statement SQLAlchemy sends. Useful when a query
    returns something unexpected and you want to see what actually ran.
    """
    cfg = load_config()
    return create_engine(build_connection_url(cfg), echo=echo)


if __name__ == "__main__":
    # Running this file directly is the Phase 0 connection test.
    print(f"Reading config from: {CONFIG_PATH}")
    engine = get_engine()

    with engine.connect() as conn:
        # @@VERSION is T-SQL specific. It returns the SQL Server edition and
        # build. If this prints, Python -> pyodbc -> ODBC driver -> SQL Server
        # is working end to end, which is the whole point of the test.
        version = conn.execute(text("SELECT @@VERSION;")).scalar()
        server = conn.execute(text("SELECT @@SERVERNAME;")).scalar()

    print(f"\nConnected to: {server}")
    print(f"\n{version}")
