"""persona progress metadata

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-24
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("personas", sa.Column("answer_count", sa.Integer(), nullable=True))
    op.add_column(
        "personas",
        sa.Column("answered_codes", JSONB(), server_default="[]", nullable=False),
    )
    op.add_column(
        "personas",
        sa.Column("persona_revision", sa.Integer(), server_default="1", nullable=False),
    )
    op.add_column(
        "personas",
        sa.Column("persona_confidence", sa.String(20), server_default="low", nullable=False),
    )
    op.add_column("personas", sa.Column("last_answered_on", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("personas", "last_answered_on")
    op.drop_column("personas", "persona_confidence")
    op.drop_column("personas", "persona_revision")
    op.drop_column("personas", "answered_codes")
    op.drop_column("personas", "answer_count")
