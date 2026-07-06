"""chat_messages — 만남 확정 후 사용자 직접 채팅 + 시스템 안내(약속 취소 등)

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-12
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_messages",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "match_id",
            UUID(as_uuid=True),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("sender_id", sa.String(128), nullable=True),
        sa.Column("kind", sa.String(20), nullable=False, server_default="user"),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_chat_messages_match_id", "chat_messages", ["match_id"])
    op.create_index(
        "ix_chat_messages_match_created", "chat_messages", ["match_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_chat_messages_match_created", table_name="chat_messages")
    op.drop_index("ix_chat_messages_match_id", table_name="chat_messages")
    op.drop_table("chat_messages")
