"""add_product_revision_parameter_table

Revision ID: m4n5o6p7q8r9
Revises: k3l4m5n6o7p8
Create Date: 2026-03-18 23:40:00.000000

"""

from __future__ import annotations

import json
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "m4n5o6p7q8r9"
down_revision: Union[str, Sequence[str], None] = "k3l4m5n6o7p8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mes_product_revision_parameter",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=False),
        sa.Column("revision_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("param_key", sa.String(length=128), nullable=False),
        sa.Column("param_category", sa.String(length=128), nullable=False),
        sa.Column("param_type", sa.String(length=16), nullable=False),
        sa.Column("param_value", sa.String(length=1024), nullable=False),
        sa.Column("param_description", sa.String(length=500), server_default=sa.text("''"), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_preset", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
        sa.CheckConstraint(
            "param_type IN ('Text', 'Link')",
            name="ck_mes_product_revision_parameter_param_type_allowed",
        ),
        sa.ForeignKeyConstraint(["product_id"], ["mes_product.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["revision_id"], ["mes_product_revision.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "revision_id",
            "param_key",
            name="uq_mes_product_revision_parameter_revision_id_param_key",
        ),
    )
    op.create_index(op.f("ix_mes_product_revision_parameter_id"), "mes_product_revision_parameter", ["id"], unique=False)
    op.create_index(op.f("ix_mes_product_revision_parameter_product_id"), "mes_product_revision_parameter", ["product_id"], unique=False)
    op.create_index(op.f("ix_mes_product_revision_parameter_revision_id"), "mes_product_revision_parameter", ["revision_id"], unique=False)
    op.create_index(op.f("ix_mes_product_revision_parameter_sort_order"), "mes_product_revision_parameter", ["sort_order"], unique=False)
    op.create_index(op.f("ix_mes_product_revision_parameter_version"), "mes_product_revision_parameter", ["version"], unique=False)

    op.add_column(
        "mes_product_parameter_history",
        sa.Column("revision_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "mes_product_parameter_history",
        sa.Column("version", sa.Integer(), nullable=True),
    )
    op.create_index(
        op.f("ix_mes_product_parameter_history_revision_id"),
        "mes_product_parameter_history",
        ["revision_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_mes_product_parameter_history_version"),
        "mes_product_parameter_history",
        ["version"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_mes_product_param_hist_revision_id",
        "mes_product_parameter_history",
        "mes_product_revision",
        ["revision_id"],
        ["id"],
        ondelete="SET NULL",
    )

    bind = op.get_bind()
    product_rows = bind.execute(
        sa.text("SELECT id, current_version FROM mes_product")
    ).mappings().all()
    current_version_by_product = {
        int(row["id"]): int(row["current_version"] or 0) for row in product_rows
    }
    current_description_rows = bind.execute(
        sa.text(
            "SELECT product_id, param_key, param_description "
            "FROM mes_product_parameter"
        )
    ).mappings().all()
    current_description_map = {
        (int(row["product_id"]), str(row["param_key"])): str(row["param_description"] or "")
        for row in current_description_rows
    }

    revision_rows = bind.execute(
        sa.text(
            "SELECT id, product_id, version, snapshot_json "
            "FROM mes_product_revision ORDER BY product_id ASC, version ASC, id ASC"
        )
    ).mappings().all()

    insert_revision_parameter = sa.text(
        """
        INSERT INTO mes_product_revision_parameter (
            product_id, revision_id, version, param_key, param_category,
            param_type, param_value, param_description, sort_order, is_preset
        ) VALUES (
            :product_id, :revision_id, :version, :param_key, :param_category,
            :param_type, :param_value, :param_description, :sort_order, :is_preset
        )
        """
    )

    revision_snapshot_lookup: dict[tuple[int, str], tuple[int, int]] = {}
    for row in revision_rows:
        revision_id = int(row["id"])
        product_id = int(row["product_id"])
        version = int(row["version"])
        snapshot_json = str(row["snapshot_json"] or "")
        if snapshot_json:
            revision_snapshot_lookup[(product_id, snapshot_json)] = (revision_id, version)
        try:
            payload = json.loads(snapshot_json or "{}")
        except (TypeError, ValueError):
            continue
        parameters = payload.get("parameters")
        if not isinstance(parameters, list):
            continue

        current_version = current_version_by_product.get(product_id)
        for index, raw_item in enumerate(parameters, start=1):
            if not isinstance(raw_item, dict):
                continue
            param_key = str(raw_item.get("name") or "").strip()
            if not param_key:
                continue
            if version == current_version:
                fallback_description = current_description_map.get((product_id, param_key), "")
            else:
                fallback_description = ""
            bind.execute(
                insert_revision_parameter,
                {
                    "product_id": product_id,
                    "revision_id": revision_id,
                    "version": version,
                    "param_key": param_key,
                    "param_category": str(raw_item.get("category") or ""),
                    "param_type": str(raw_item.get("type") or "Text"),
                    "param_value": str(raw_item.get("value") or ""),
                    "param_description": str(raw_item.get("description") or fallback_description),
                    "sort_order": int(raw_item.get("sort_order") or index),
                    "is_preset": bool(raw_item.get("is_preset") or False),
                },
            )

    history_rows = bind.execute(
        sa.text(
            "SELECT id, product_id, after_snapshot "
            "FROM mes_product_parameter_history ORDER BY id ASC"
        )
    ).mappings().all()
    update_history_revision = sa.text(
        """
        UPDATE mes_product_parameter_history
        SET revision_id = :revision_id,
            version = :version
        WHERE id = :history_id
        """
    )
    for row in history_rows:
        product_id = int(row["product_id"])
        after_snapshot = str(row["after_snapshot"] or "")
        match = revision_snapshot_lookup.get((product_id, after_snapshot))
        if match is None:
            continue
        revision_id, version = match
        bind.execute(
            update_history_revision,
            {
                "history_id": int(row["id"]),
                "revision_id": revision_id,
                "version": version,
            },
        )


def downgrade() -> None:
    op.drop_constraint(
        "fk_mes_product_param_hist_revision_id",
        "mes_product_parameter_history",
        type_="foreignkey",
    )
    op.drop_index(op.f("ix_mes_product_parameter_history_version"), table_name="mes_product_parameter_history")
    op.drop_index(op.f("ix_mes_product_parameter_history_revision_id"), table_name="mes_product_parameter_history")
    op.drop_column("mes_product_parameter_history", "version")
    op.drop_column("mes_product_parameter_history", "revision_id")

    op.drop_index(op.f("ix_mes_product_revision_parameter_version"), table_name="mes_product_revision_parameter")
    op.drop_index(op.f("ix_mes_product_revision_parameter_sort_order"), table_name="mes_product_revision_parameter")
    op.drop_index(op.f("ix_mes_product_revision_parameter_revision_id"), table_name="mes_product_revision_parameter")
    op.drop_index(op.f("ix_mes_product_revision_parameter_product_id"), table_name="mes_product_revision_parameter")
    op.drop_index(op.f("ix_mes_product_revision_parameter_id"), table_name="mes_product_revision_parameter")
    op.drop_table("mes_product_revision_parameter")
