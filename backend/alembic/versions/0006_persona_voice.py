"""persona voice v2 — 측정 말투 통계·실측 발화 뱅크·정답지

Revision ID: 0006
Revises: 0005
Create Date: 2026-07-04
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("personas", sa.Column("voice_stats", JSONB(), nullable=True))
    op.add_column(
        "personas",
        sa.Column("sample_bank", JSONB(), server_default="[]", nullable=False),
    )
    op.add_column("personas", sa.Column("voice_confidence", sa.Float(), nullable=True))
    op.add_column(
        "personas",
        sa.Column("response_preferences", JSONB(), server_default="[]", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("personas", "response_preferences")
    op.drop_column("personas", "voice_confidence")
    op.drop_column("personas", "sample_bank")
    op.drop_column("personas", "voice_stats")
