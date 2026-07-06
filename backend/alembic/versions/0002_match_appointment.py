"""matches: appointment_ready + accepted_by (눈치 약속조율/수락 플로우)

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-11
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "matches",
        sa.Column(
            "appointment_ready",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "matches",
        sa.Column(
            "accepted_by",
            ARRAY(sa.String(128)),
            nullable=False,
            server_default="{}",
        ),
    )


def downgrade() -> None:
    op.drop_column("matches", "accepted_by")
    op.drop_column("matches", "appointment_ready")
