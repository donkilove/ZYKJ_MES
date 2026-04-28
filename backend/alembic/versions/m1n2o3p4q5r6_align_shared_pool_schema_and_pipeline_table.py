"""align shared pool schema and pipeline table

Revision ID: m1n2o3p4q5r6
Revises: z8a9b0c1d2e3
Create Date: 2026-04-28 12:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "m1n2o3p4q5r6"
down_revision: Union[str, Sequence[str], None] = "z8a9b0c1d2e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    sub_order_columns = {col["name"] for col in inspector.get_columns("mes_order_sub_order")}
    if "assigned_quantity" in sub_order_columns:
        op.drop_constraint(
            "ck_mes_order_sub_order_assigned_quantity_non_negative",
            "mes_order_sub_order",
            type_="check",
        )
        op.drop_column("mes_order_sub_order", "assigned_quantity")
    if "is_visible" in sub_order_columns:
        op.drop_column("mes_order_sub_order", "is_visible")

    pipeline_tables = set(inspector.get_table_names())
    if "mes_order_sub_order_pipeline_instance" in pipeline_tables and "mes_process_pipeline_instance" not in pipeline_tables:
        op.rename_table(
            "mes_order_sub_order_pipeline_instance",
            "mes_process_pipeline_instance",
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_order_sub_order_pipeline_instance_order_process RENAME TO ix_mes_process_pipeline_instance_order_process"
            )
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_order_sub_order_pipeline_instance_is_active RENAME TO ix_mes_process_pipeline_instance_is_active"
            )
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_order_sub_order_pipeline_instance_pipeline_link_id RENAME TO ix_mes_process_pipeline_instance_pipeline_link_id"
            )
        )
        op.execute(
            sa.text(
                "ALTER TABLE mes_process_pipeline_instance RENAME CONSTRAINT uq_mes_order_sub_order_pipeline_instance_sub_order_seq TO uq_mes_process_pipeline_instance_sub_order_seq"
            )
        )
        op.execute(
            sa.text(
                "ALTER TABLE mes_process_pipeline_instance RENAME CONSTRAINT uq_mes_order_sub_order_pipeline_instance_no TO uq_mes_process_pipeline_instance_no"
            )
        )

    inspector = sa.inspect(bind)
    pipeline_columns = {col["name"] for col in inspector.get_columns("mes_process_pipeline_instance")}
    if "pipeline_sub_order_no" in pipeline_columns and "pipeline_instance_no" not in pipeline_columns:
        op.alter_column(
            "mes_process_pipeline_instance",
            "pipeline_sub_order_no",
            new_column_name="pipeline_instance_no",
        )

    foreign_keys = {fk["name"] for fk in inspector.get_foreign_keys("mes_first_article_review_session")}
    if "mes_process_pipeline_instance" in set(inspector.get_table_names()):
        if "fk_mes_first_article_review_session_pipeline_instance_id_mes_order_sub_order_pipeline_instance" in foreign_keys:
            op.drop_constraint(
                "fk_mes_first_article_review_session_pipeline_instance_id_mes_order_sub_order_pipeline_instance",
                "mes_first_article_review_session",
                type_="foreignkey",
            )
            op.create_foreign_key(
                "fk_mes_first_article_review_session_pipeline_instance_id_mes_process_pipeline_instance",
                "mes_first_article_review_session",
                "mes_process_pipeline_instance",
                ["pipeline_instance_id"],
                ["id"],
                ondelete="SET NULL",
            )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    first_article_fks = {fk["name"] for fk in inspector.get_foreign_keys("mes_first_article_review_session")}
    if "fk_mes_first_article_review_session_pipeline_instance_id_mes_process_pipeline_instance" in first_article_fks:
        op.drop_constraint(
            "fk_mes_first_article_review_session_pipeline_instance_id_mes_process_pipeline_instance",
            "mes_first_article_review_session",
            type_="foreignkey",
        )
        op.create_foreign_key(
            "fk_mes_first_article_review_session_pipeline_instance_id_mes_order_sub_order_pipeline_instance",
            "mes_first_article_review_session",
            "mes_order_sub_order_pipeline_instance",
            ["pipeline_instance_id"],
            ["id"],
            ondelete="SET NULL",
        )

    pipeline_tables = set(inspector.get_table_names())
    if "mes_process_pipeline_instance" in pipeline_tables:
        pipeline_columns = {col["name"] for col in inspector.get_columns("mes_process_pipeline_instance")}
        if "pipeline_instance_no" in pipeline_columns and "pipeline_sub_order_no" not in pipeline_columns:
            op.alter_column(
                "mes_process_pipeline_instance",
                "pipeline_instance_no",
                new_column_name="pipeline_sub_order_no",
            )
        op.execute(
            sa.text(
                "ALTER TABLE mes_process_pipeline_instance RENAME CONSTRAINT uq_mes_process_pipeline_instance_sub_order_seq TO uq_mes_order_sub_order_pipeline_instance_sub_order_seq"
            )
        )
        op.execute(
            sa.text(
                "ALTER TABLE mes_process_pipeline_instance RENAME CONSTRAINT uq_mes_process_pipeline_instance_no TO uq_mes_order_sub_order_pipeline_instance_no"
            )
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_process_pipeline_instance_order_process RENAME TO ix_mes_order_sub_order_pipeline_instance_order_process"
            )
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_process_pipeline_instance_is_active RENAME TO ix_mes_order_sub_order_pipeline_instance_is_active"
            )
        )
        op.execute(
            sa.text(
                "ALTER INDEX IF EXISTS ix_mes_process_pipeline_instance_pipeline_link_id RENAME TO ix_mes_order_sub_order_pipeline_instance_pipeline_link_id"
            )
        )
        op.rename_table(
            "mes_process_pipeline_instance",
            "mes_order_sub_order_pipeline_instance",
        )

    sub_order_columns = {col["name"] for col in inspector.get_columns("mes_order_sub_order")}
    if "assigned_quantity" not in sub_order_columns:
        op.add_column(
            "mes_order_sub_order",
            sa.Column("assigned_quantity", sa.Integer(), nullable=False, server_default=sa.text("0")),
        )
        op.create_check_constraint(
            "ck_mes_order_sub_order_assigned_quantity_non_negative",
            "mes_order_sub_order",
            "assigned_quantity >= 0",
        )
    if "is_visible" not in sub_order_columns:
        op.add_column(
            "mes_order_sub_order",
            sa.Column("is_visible", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        )
