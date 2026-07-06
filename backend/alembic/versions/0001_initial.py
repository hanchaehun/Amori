"""initial schema — 8 tables + pgvector

Revision ID: 0001
Revises:
Create Date: 2026-06-10
"""

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects.postgresql import ARRAY, JSONB

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

EMBEDDING_DIM = 1024


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "users",
        sa.Column("id", sa.String(128), primary_key=True),
        sa.Column("email", sa.String(255)),
        sa.Column("display_name", sa.String(100)),
        sa.Column("birth_date", sa.Date()),
        sa.Column("gender", sa.String(20)),
        sa.Column("interest_gender", sa.String(20)),
        sa.Column("photo_url", sa.Text()),
        sa.Column("fcm_token", sa.Text()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "personas",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(128),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
            index=True,
        ),
        sa.Column("traits", JSONB(), nullable=False),
        sa.Column("communication_style", sa.String(200), nullable=False),
        sa.Column("humor_style", sa.String(200), nullable=False),
        sa.Column("value_keywords", JSONB(), nullable=False),
        sa.Column("speech_style", JSONB(), nullable=False),
        sa.Column("sample_messages", JSONB(), nullable=False),
        sa.Column("embedding", Vector(EMBEDDING_DIM)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_personas_embedding_hnsw",
        "personas",
        ["embedding"],
        postgresql_using="hnsw",
        postgresql_with={"m": 16, "ef_construction": 64},
        postgresql_ops={"embedding": "vector_cosine_ops"},
    )

    op.create_table(
        "matches",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("participant_ids", ARRAY(sa.String(128)), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("score", sa.Float()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_matches_participant_ids",
        "matches",
        ["participant_ids"],
        postgresql_using="gin",
    )

    op.create_table(
        "simulation_jobs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "match_id",
            sa.Uuid(),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("requested_by", sa.String(128), nullable=False, index=True),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("turns", JSONB()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
    )

    op.create_table(
        "reports",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "match_id",
            sa.Uuid(),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
            index=True,
        ),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("findings", JSONB(), nullable=False),
        sa.Column("warnings", JSONB(), nullable=False),
        sa.Column("places", JSONB(), nullable=False),
        sa.Column("starters", JSONB(), nullable=False),
        sa.Column("tip", sa.Text()),
        sa.Column("ai_generated", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "meet_requests",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "match_id",
            sa.Uuid(),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("requester_id", sa.String(128), nullable=False, index=True),
        sa.Column("receiver_id", sa.String(128), nullable=False, index=True),
        sa.Column("message", sa.Text()),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "feedback",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "match_id",
            sa.Uuid(),
            sa.ForeignKey("matches.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("user_id", sa.String(128), nullable=False, index=True),
        sa.Column("impression", sa.String(20), nullable=False),
        sa.Column("accuracy", sa.Float(), nullable=False),
        sa.Column("next_step", sa.String(50), nullable=False),
        sa.Column("note", sa.Text()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "llm_call_logs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("endpoint", sa.String(100), nullable=False),
        sa.Column("provider", sa.String(50), nullable=False),
        sa.Column("request_body", JSONB()),
        sa.Column("response_status", sa.Integer(), nullable=False),
        sa.Column("response_time_ms", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.String(128), index=True),
        sa.Column("request_id", sa.String(64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("llm_call_logs")
    op.drop_table("feedback")
    op.drop_table("meet_requests")
    op.drop_table("reports")
    op.drop_table("simulation_jobs")
    op.drop_table("matches")
    op.drop_table("personas")
    op.drop_table("users")
