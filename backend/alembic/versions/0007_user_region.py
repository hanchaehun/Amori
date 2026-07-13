"""user region — 활동 지역(시/도). 매칭 랭킹의 같은 지역 가점에 쓴다

Revision ID: 0007
Revises: 0006
Create Date: 2026-07-13
"""

import sqlalchemy as sa
from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("region", sa.String(30), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "region")
