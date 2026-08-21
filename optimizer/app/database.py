import os
from contextlib import contextmanager
from typing import Generator

import psycopg
from psycopg import Connection
from psycopg.rows import dict_row


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://aviation_user:aviation_pass@postgres:5432/aviation_db",
)


@contextmanager
def get_connection() -> Generator[Connection, None, None]:
    """
    Open a PostgreSQL connection.

    On successful exit, psycopg commits the transaction.
    If an exception escapes the context, psycopg rolls it back.
    """
    with psycopg.connect(
        DATABASE_URL,
        row_factory=dict_row,
    ) as connection:
        yield connection
