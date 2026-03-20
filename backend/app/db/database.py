from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import inspect, text
from datetime import datetime, timezone
from uuid import uuid4
from app.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
)

AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Create all tables. Used for local dev; in production use Alembic migrations."""
    async with engine.begin() as conn:
        from app.models import user, habit, habit_log, chat_session, chat_message, user_activity  # noqa
        from app.models import friendship, achievement, notification  # noqa
        from app.models import mood_log, challenge, device_token  # noqa
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(_run_dev_chat_migrations)


def _run_dev_chat_migrations(sync_conn):
    """Apply lightweight dev-only migrations for chat sessions."""
    inspector = inspect(sync_conn)
    table_names = set(inspector.get_table_names())

    if "chat_sessions" not in table_names:
        sync_conn.execute(
            text(
                """
                CREATE TABLE chat_sessions (
                    id VARCHAR(36) PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    title VARCHAR(255) NOT NULL DEFAULT 'Новый чат',
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
                )
                """
            )
        )

    if "device_tokens" not in table_names:
        sync_conn.execute(
            text(
                """
                CREATE TABLE device_tokens (
                    id INTEGER PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    token VARCHAR(512) NOT NULL,
                    platform VARCHAR(32) NOT NULL DEFAULT 'unknown',
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
                )
                """
            )
        )
        sync_conn.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_token ON device_tokens (token)")
        )

    user_columns = {column["name"] for column in inspector.get_columns("users")}
    if "is_email_verified" not in user_columns:
        sync_conn.execute(
            text("ALTER TABLE users ADD COLUMN is_email_verified BOOLEAN DEFAULT FALSE")
        )
    if "email_verification_token" not in user_columns:
        sync_conn.execute(
            text("ALTER TABLE users ADD COLUMN email_verification_token VARCHAR(255)")
        )
    if "email_verification_expires_at" not in user_columns:
        sync_conn.execute(
            text("ALTER TABLE users ADD COLUMN email_verification_expires_at TIMESTAMP WITH TIME ZONE")
        )

    chat_message_columns = {
        column["name"] for column in inspector.get_columns("chat_messages")
    }
    if "session_id" not in chat_message_columns:
        sync_conn.execute(
            text("ALTER TABLE chat_messages ADD COLUMN session_id VARCHAR(36)")
        )
    if "suggested_habits" not in chat_message_columns:
        sync_conn.execute(
            text("ALTER TABLE chat_messages ADD COLUMN suggested_habits JSON")
        )
    if "suggested_bundle_name" not in chat_message_columns:
        sync_conn.execute(
            text("ALTER TABLE chat_messages ADD COLUMN suggested_bundle_name VARCHAR(255)")
        )

    existing_sessions = set()
    if "chat_sessions" in inspector.get_table_names():
        result = sync_conn.execute(text("SELECT id FROM chat_sessions"))
        existing_sessions = {row[0] for row in result}

    orphan_users = sync_conn.execute(
        text(
            "SELECT DISTINCT user_id FROM chat_messages WHERE session_id IS NULL OR session_id = ''"
        )
    ).fetchall()

    now = datetime.now(timezone.utc)
    for row in orphan_users:
        user_id = row[0]
        chat_id = str(uuid4())
        while chat_id in existing_sessions:
            chat_id = str(uuid4())

        range_row = sync_conn.execute(
            text(
                """
                SELECT MIN(timestamp) AS created_at, MAX(timestamp) AS updated_at
                FROM chat_messages
                WHERE user_id = :user_id AND (session_id IS NULL OR session_id = '')
                """
            ),
            {"user_id": user_id},
        ).first()
        created_at = (range_row[0] if range_row and range_row[0] else now)
        updated_at = (range_row[1] if range_row and range_row[1] else created_at)

        sync_conn.execute(
            text(
                """
                INSERT INTO chat_sessions (id, user_id, title, created_at, updated_at)
                VALUES (:id, :user_id, :title, :created_at, :updated_at)
                """
            ),
            {
                "id": chat_id,
                "user_id": user_id,
                "title": "Архивный чат",
                "created_at": created_at,
                "updated_at": updated_at,
            },
        )
        sync_conn.execute(
            text(
                """
                UPDATE chat_messages
                SET session_id = :session_id
                WHERE user_id = :user_id AND (session_id IS NULL OR session_id = '')
                """
            ),
            {"session_id": chat_id, "user_id": user_id},
        )
        existing_sessions.add(chat_id)

