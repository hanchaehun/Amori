"""user_blocks + abuse_reports — 사용자 간 차단·신고 (UGC 안전, App Store 1.2)

Revision ID: 0011
Revises: 0010
Create Date: 2026-07-21
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_blocks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("blocker_id", sa.String(128), nullable=False),
        sa.Column("blocked_id", sa.String(128), nullable=False),
        sa.Column(
            "match_id",
            UUID(as_uuid=True),
            sa.ForeignKey("matches.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_user_blocks_pair"),
    )
    op.create_index("ix_user_blocks_blocker_id", "user_blocks", ["blocker_id"])
    op.create_index("ix_user_blocks_blocked_id", "user_blocks", ["blocked_id"])

    op.create_table(
        "abuse_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("reporter_id", sa.String(128), nullable=False),
        sa.Column("reported_id", sa.String(128), nullable=False),
        sa.Column(
            "match_id",
            UUID(as_uuid=True),
            sa.ForeignKey("matches.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reason", sa.String(20), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_abuse_reports_reporter_id", "abuse_reports", ["reporter_id"])
    op.create_index("ix_abuse_reports_reported_id", "abuse_reports", ["reported_id"])


def downgrade() -> None:
    op.drop_index("ix_abuse_reports_reported_id", table_name="abuse_reports")
    op.drop_index("ix_abuse_reports_reporter_id", table_name="abuse_reports")
    op.drop_table("abuse_reports")
    op.drop_index("ix_user_blocks_blocked_id", table_name="user_blocks")
    op.drop_index("ix_user_blocks_blocker_id", table_name="user_blocks")
    op.drop_table("user_blocks")
