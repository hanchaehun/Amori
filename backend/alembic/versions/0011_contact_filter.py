"""지인 필터 — users.phone_number/phone_hash/email_hash + blocked_contacts

phone_number는 가입 폼 자기신고 번호(2026-07-19 결정 — 지인 필터 실효화),
본인인증(PASS) 도입 시 인증된 번호로 덮어쓴다. blocked_contacts는 주소록
동기화('contacts')와 수동 등록('manual')의 식별자 SHA-256 해시만 담는다 —
제3자 연락처 원문은 저장하지 않는다.

Revision ID: 0011
Revises: 0010
Create Date: 2026-07-19
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("phone_number", sa.String(20), nullable=True))
    op.add_column("users", sa.Column("phone_hash", sa.String(64), nullable=True))
    op.add_column("users", sa.Column("email_hash", sa.String(64), nullable=True))
    op.create_index("ix_users_phone_hash", "users", ["phone_hash"])
    op.create_index("ix_users_email_hash", "users", ["email_hash"])

    op.create_table(
        "blocked_contacts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(128),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("contact_hash", sa.String(64), nullable=False),
        sa.Column("kind", sa.String(10), nullable=False),
        sa.Column("source", sa.String(10), nullable=False),
        sa.Column("label", sa.String(60), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "contact_hash", name="uq_blocked_contacts_user_hash"
        ),
    )
    op.create_index("ix_blocked_contacts_user_id", "blocked_contacts", ["user_id"])
    op.create_index(
        "ix_blocked_contacts_contact_hash", "blocked_contacts", ["contact_hash"]
    )


def downgrade() -> None:
    op.drop_table("blocked_contacts")
    op.drop_index("ix_users_email_hash", table_name="users")
    op.drop_index("ix_users_phone_hash", table_name="users")
    op.drop_column("users", "email_hash")
    op.drop_column("users", "phone_hash")
    op.drop_column("users", "phone_number")
