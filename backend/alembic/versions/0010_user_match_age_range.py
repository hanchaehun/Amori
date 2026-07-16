"""users.match_age_older/younger — 매칭 허용 나이 (위로/아래로 N살, NULL = 기본 5)

Revision ID: 0010
Revises: 0009
Create Date: 2026-07-16
"""

import sqlalchemy as sa
from alembic import op

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("match_age_older", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("match_age_younger", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "match_age_younger")
    op.drop_column("users", "match_age_older")
