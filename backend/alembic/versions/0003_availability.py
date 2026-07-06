"""users.available_slots + matches.appointment_slot (실일정 기반 약속 조율)

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-12
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("available_slots", JSONB(), nullable=False, server_default="[]"),
    )
    op.add_column(
        "matches",
        sa.Column("appointment_slot", JSONB(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("matches", "appointment_slot")
    op.drop_column("users", "available_slots")
