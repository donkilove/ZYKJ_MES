"""sunset page visibility and add authz audit

Revision ID: c4e6f8a1b2d3
Revises: a1c3e5f7b9d2
Create Date: 2026-03-09 18:40:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c4e6f8a1b2d3"
down_revision: Union[str, Sequence[str], None] = "a1c3e5f7b9d2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


LEGACY_PERMISSION_CODES = (
    "page.page_visibility_config.view",
    "system.page_visibility_config.view",
    "system.page_visibility_config.update",
    "feature.system.page_visibility_legacy.manage",
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "sys_authz_change_log",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("module_code", sa.String(length=64), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("change_type", sa.String(length=32), nullable=False, server_default=sa.text("'apply'")),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=64), nullable=True),
        sa.Column("rollback_of_change_log_id", sa.Integer(), nullable=True),
        sa.Column("snapshot_json", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_authz_change_log_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["rollback_of_change_log_id"],
            ["sys_authz_change_log.id"],
            name=op.f("fk_sys_authz_change_log_rollback_of_change_log_id_sys_authz_change_log"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_authz_change_log")),
    )
    op.create_index(op.f("ix_sys_authz_change_log_id"), "sys_authz_change_log", ["id"], unique=False)
    op.create_index(
        op.f("ix_sys_authz_change_log_module_code"),
        "sys_authz_change_log",
        ["module_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_revision"),
        "sys_authz_change_log",
        ["revision"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_operator_user_id"),
        "sys_authz_change_log",
        ["operator_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_rollback_of_change_log_id"),
        "sys_authz_change_log",
        ["rollback_of_change_log_id"],
        unique=False,
    )

    op.create_table(
        "sys_authz_change_log_item",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("change_log_id", sa.Integer(), nullable=False),
        sa.Column("role_code", sa.String(length=64), nullable=False),
        sa.Column("role_name", sa.String(length=128), nullable=False),
        sa.Column("readonly", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("before_capability_codes", sa.JSON(), nullable=False),
        sa.Column("after_capability_codes", sa.JSON(), nullable=False),
        sa.Column("added_capability_codes", sa.JSON(), nullable=False),
        sa.Column("removed_capability_codes", sa.JSON(), nullable=False),
        sa.Column("auto_linked_dependencies", sa.JSON(), nullable=False),
        sa.Column("effective_capability_codes", sa.JSON(), nullable=False),
        sa.Column("effective_page_permission_codes", sa.JSON(), nullable=False),
        sa.Column("updated_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["change_log_id"],
            ["sys_authz_change_log.id"],
            name=op.f("fk_sys_authz_change_log_item_change_log_id_sys_authz_change_log"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_authz_change_log_item")),
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_item_id"),
        "sys_authz_change_log_item",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_item_change_log_id"),
        "sys_authz_change_log_item",
        ["change_log_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_authz_change_log_item_role_code"),
        "sys_authz_change_log_item",
        ["role_code"],
        unique=False,
    )

    op.execute(
        sa.text(
            "DELETE FROM sys_role_permission_grant WHERE permission_code IN :codes"
        ).bindparams(sa.bindparam("codes", expanding=True)),
        {"codes": LEGACY_PERMISSION_CODES},
    )
    op.execute(
        sa.text(
            "DELETE FROM sys_permission_catalog WHERE permission_code IN :codes"
        ).bindparams(sa.bindparam("codes", expanding=True)),
        {"codes": LEGACY_PERMISSION_CODES},
    )

    op.drop_index(op.f("ix_sys_page_visibility_role_code"), table_name="sys_page_visibility")
    op.drop_index(op.f("ix_sys_page_visibility_page_code"), table_name="sys_page_visibility")
    op.drop_index(op.f("ix_sys_page_visibility_id"), table_name="sys_page_visibility")
    op.drop_table("sys_page_visibility")


def downgrade() -> None:
    """Downgrade schema."""
    op.create_table(
        "sys_page_visibility",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("page_code", sa.String(length=64), nullable=False),
        sa.Column("role_code", sa.String(length=64), nullable=False),
        sa.Column("is_visible", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_page_visibility")),
        sa.UniqueConstraint("page_code", "role_code", name="uq_sys_page_visibility_page_code_role_code"),
    )
    op.create_index(op.f("ix_sys_page_visibility_id"), "sys_page_visibility", ["id"], unique=False)
    op.create_index(
        op.f("ix_sys_page_visibility_page_code"),
        "sys_page_visibility",
        ["page_code"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_page_visibility_role_code"),
        "sys_page_visibility",
        ["role_code"],
        unique=False,
    )

    permission_table = sa.table(
        "sys_permission_catalog",
        sa.column("permission_code", sa.String(length=128)),
        sa.column("permission_name", sa.String(length=128)),
        sa.column("module_code", sa.String(length=64)),
        sa.column("resource_type", sa.String(length=32)),
        sa.column("parent_permission_code", sa.String(length=128)),
        sa.column("is_enabled", sa.Boolean()),
    )
    op.bulk_insert(
        permission_table,
        [
            {
                "permission_code": "page.page_visibility_config.view",
                "permission_name": "页面访问：页面可见性配置（旧）",
                "module_code": "system",
                "resource_type": "page",
                "parent_permission_code": "page.user.view",
                "is_enabled": True,
            },
            {
                "permission_code": "system.page_visibility_config.view",
                "permission_name": "查看页面可见性配置（旧）",
                "module_code": "system",
                "resource_type": "action",
                "parent_permission_code": "page.page_visibility_config.view",
                "is_enabled": True,
            },
            {
                "permission_code": "system.page_visibility_config.update",
                "permission_name": "更新页面可见性配置（旧）",
                "module_code": "system",
                "resource_type": "action",
                "parent_permission_code": "page.page_visibility_config.view",
                "is_enabled": True,
            },
            {
                "permission_code": "feature.system.page_visibility_legacy.manage",
                "permission_name": "管理页面可见性（旧）",
                "module_code": "system",
                "resource_type": "feature",
                "parent_permission_code": "page.function_permission_config.view",
                "is_enabled": True,
            },
        ],
    )

    op.drop_index(op.f("ix_sys_authz_change_log_item_role_code"), table_name="sys_authz_change_log_item")
    op.drop_index(op.f("ix_sys_authz_change_log_item_change_log_id"), table_name="sys_authz_change_log_item")
    op.drop_index(op.f("ix_sys_authz_change_log_item_id"), table_name="sys_authz_change_log_item")
    op.drop_table("sys_authz_change_log_item")

    op.drop_index(op.f("ix_sys_authz_change_log_rollback_of_change_log_id"), table_name="sys_authz_change_log")
    op.drop_index(op.f("ix_sys_authz_change_log_operator_user_id"), table_name="sys_authz_change_log")
    op.drop_index(op.f("ix_sys_authz_change_log_revision"), table_name="sys_authz_change_log")
    op.drop_index(op.f("ix_sys_authz_change_log_module_code"), table_name="sys_authz_change_log")
    op.drop_index(op.f("ix_sys_authz_change_log_id"), table_name="sys_authz_change_log")
    op.drop_table("sys_authz_change_log")
