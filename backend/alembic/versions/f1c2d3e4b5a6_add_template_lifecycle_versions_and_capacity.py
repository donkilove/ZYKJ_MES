"""add template lifecycle, versions and capacity fields

Revision ID: f1c2d3e4b5a6
Revises: e7b9c1d2a3f4
Create Date: 2026-03-06 18:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f1c2d3e4b5a6"
down_revision: Union[str, Sequence[str], None] = "e7b9c1d2a3f4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _seed_initial_template_revisions() -> None:
    conn = op.get_bind()

    templates = conn.execute(
        sa.text(
            """
            SELECT id, published_version
            FROM mes_product_process_template
            ORDER BY id ASC
            """
        )
    ).mappings()

    for template in templates:
        template_id = int(template["id"])
        version = int(template["published_version"] or 0)
        if version <= 0:
            continue

        conn.execute(
            sa.text(
                """
                INSERT INTO mes_product_process_template_revision
                    (template_id, version, action, note, source_revision_id, created_by_user_id, created_at, updated_at)
                SELECT
                    id,
                    :version,
                    'publish',
                    '历史模板迁移初始化版本',
                    NULL,
                    updated_by_user_id,
                    COALESCE(updated_at, CURRENT_TIMESTAMP),
                    COALESCE(updated_at, CURRENT_TIMESTAMP)
                FROM mes_product_process_template
                WHERE id = :template_id
                """
            ),
            {"template_id": template_id, "version": version},
        )
        revision_id = conn.execute(
            sa.text(
                """
                SELECT id
                FROM mes_product_process_template_revision
                WHERE template_id = :template_id AND version = :version
                """
            ),
            {"template_id": template_id, "version": version},
        ).scalar_one()

        conn.execute(
            sa.text(
                """
                INSERT INTO mes_product_process_template_revision_step
                    (
                        revision_id,
                        step_order,
                        stage_id,
                        stage_code,
                        stage_name,
                        process_id,
                        process_code,
                        process_name,
                        standard_minutes,
                        capacity_per_hour,
                        created_at,
                        updated_at
                    )
                SELECT
                    :revision_id,
                    step_order,
                    stage_id,
                    stage_code,
                    stage_name,
                    process_id,
                    process_code,
                    process_name,
                    COALESCE(standard_minutes, 0),
                    COALESCE(capacity_per_hour, 0),
                    COALESCE(updated_at, CURRENT_TIMESTAMP),
                    COALESCE(updated_at, CURRENT_TIMESTAMP)
                FROM mes_product_process_template_step
                WHERE template_id = :template_id
                ORDER BY step_order ASC, id ASC
                """
            ),
            {"revision_id": revision_id, "template_id": template_id},
        )


def upgrade() -> None:
    """Upgrade schema."""

    op.add_column(
        "mes_product_process_template",
        sa.Column(
            "lifecycle_status",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'draft'"),
        ),
    )
    op.add_column(
        "mes_product_process_template",
        sa.Column(
            "published_version",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_lifecycle_status"),
        "mes_product_process_template",
        ["lifecycle_status"],
        unique=False,
    )

    op.add_column(
        "mes_product_process_template_step",
        sa.Column(
            "standard_minutes",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "mes_product_process_template_step",
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

    op.add_column(
        "sys_craft_system_master_template_step",
        sa.Column(
            "standard_minutes",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "sys_craft_system_master_template_step",
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )

    op.create_table(
        "mes_product_process_template_revision",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("note", sa.String(length=256), nullable=True),
        sa.Column("source_revision_id", sa.Integer(), nullable=True),
        sa.Column("created_by_user_id", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["sys_user.id"],
            name=op.f("fk_ppt_rev_created_by_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["source_revision_id"],
            ["mes_product_process_template_revision.id"],
            name=op.f("fk_ppt_rev_source_revision"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["template_id"],
            ["mes_product_process_template.id"],
            name=op.f("fk_ppt_rev_template"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_process_template_revision")),
        sa.UniqueConstraint(
            "template_id",
            "version",
            name="uq_mes_product_process_template_revision_template_id_version",
        ),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_id"),
        "mes_product_process_template_revision",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_template_id"),
        "mes_product_process_template_revision",
        ["template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_source_revision_id"),
        "mes_product_process_template_revision",
        ["source_revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_created_by_user_id"),
        "mes_product_process_template_revision",
        ["created_by_user_id"],
        unique=False,
    )

    op.create_table(
        "mes_product_process_template_revision_step",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("revision_id", sa.Integer(), nullable=False),
        sa.Column("step_order", sa.Integer(), nullable=False),
        sa.Column("stage_id", sa.Integer(), nullable=False),
        sa.Column("stage_code", sa.String(length=64), nullable=False),
        sa.Column("stage_name", sa.String(length=128), nullable=False),
        sa.Column("process_id", sa.Integer(), nullable=False),
        sa.Column("process_code", sa.String(length=64), nullable=False),
        sa.Column("process_name", sa.String(length=128), nullable=False),
        sa.Column("standard_minutes", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "capacity_per_hour",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["process_id"],
            ["mes_process.id"],
            name=op.f("fk_ppt_rev_step_process"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["revision_id"],
            ["mes_product_process_template_revision.id"],
            name=op.f("fk_ppt_rev_step_revision"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["stage_id"],
            ["mes_process_stage.id"],
            name=op.f("fk_ppt_rev_step_stage"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_mes_product_process_template_revision_step")),
        sa.UniqueConstraint(
            "revision_id",
            "step_order",
            name="uq_ppt_rev_step_revision_id_step_order",
        ),
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_id"),
        "mes_product_process_template_revision_step",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_revision_id"),
        "mes_product_process_template_revision_step",
        ["revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_stage_id"),
        "mes_product_process_template_revision_step",
        ["stage_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_stage_code"),
        "mes_product_process_template_revision_step",
        ["stage_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_process_id"),
        "mes_product_process_template_revision_step",
        ["process_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_process_template_revision_step_process_code"),
        "mes_product_process_template_revision_step",
        ["process_code"],
        unique=False,
    )

    # Existing templates are treated as published snapshots.
    op.execute(
        sa.text(
            """
            UPDATE mes_product_process_template
            SET lifecycle_status = 'published',
                published_version = CASE
                    WHEN COALESCE(version, 0) > 0 THEN version
                    ELSE 1
                END
            """
        )
    )
    _seed_initial_template_revisions()


def downgrade() -> None:
    """Downgrade schema."""

    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_process_code"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_process_id"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_stage_code"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_stage_id"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_revision_id"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_step_id"),
        table_name="mes_product_process_template_revision_step",
    )
    op.drop_table("mes_product_process_template_revision_step")

    op.drop_index(
        op.f("ix_mes_product_process_template_revision_created_by_user_id"),
        table_name="mes_product_process_template_revision",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_source_revision_id"),
        table_name="mes_product_process_template_revision",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_template_id"),
        table_name="mes_product_process_template_revision",
    )
    op.drop_index(
        op.f("ix_mes_product_process_template_revision_id"),
        table_name="mes_product_process_template_revision",
    )
    op.drop_table("mes_product_process_template_revision")

    op.drop_column("sys_craft_system_master_template_step", "capacity_per_hour")
    op.drop_column("sys_craft_system_master_template_step", "standard_minutes")

    op.drop_column("mes_product_process_template_step", "capacity_per_hour")
    op.drop_column("mes_product_process_template_step", "standard_minutes")

    op.drop_index(op.f("ix_mes_product_process_template_lifecycle_status"), table_name="mes_product_process_template")
    op.drop_column("mes_product_process_template", "published_version")
    op.drop_column("mes_product_process_template", "lifecycle_status")
