"""P0-B/P0-E — personas 심리 기저층 2컬럼 + users.mbti

Revision ID: 0008
Revises: 0007
Create Date: 2026-07-15
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("personas", sa.Column("psych_profile", JSONB, nullable=True))
    op.add_column("personas", sa.Column("conversation_policy", JSONB, nullable=True))
    op.add_column("users", sa.Column("mbti", sa.String(4), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "mbti")
    op.drop_column("personas", "conversation_policy")
    op.drop_column("personas", "psych_profile")
