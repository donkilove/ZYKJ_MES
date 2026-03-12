"""upgrade user module v1 schema

Revision ID: f3d4e5a6b7c8
Revises: c4e6f8a1b2d3
Create Date: 2026-03-12 21:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f3d4e5a6b7c8"
down_revision: Union[str, Sequence[str], None] = "c4e6f8a1b2d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


BUILTIN_ROLE_CODES = (
    "system_admin",
    "production_admin",
    "quality_admin",
    "operator",
    "maintenance_staff",
)


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("sys_role", sa.Column("description", sa.String(length=255), nullable=True))
    op.add_column(
        "sys_role",
        sa.Column(
            "role_type",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'custom'"),
        ),
    )
    op.add_column(
        "sys_role",
        sa.Column(
            "is_builtin",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "sys_role",
        sa.Column(
            "is_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.create_index(op.f("ix_sys_role_role_type"), "sys_role", ["role_type"], unique=False)
    op.create_index(op.f("ix_sys_role_is_builtin"), "sys_role", ["is_builtin"], unique=False)
    op.create_index(op.f("ix_sys_role_is_enabled"), "sys_role", ["is_enabled"], unique=False)

    bind = op.get_bind()
    bind.execute(
        sa.text(
            "UPDATE sys_role SET is_builtin = true, role_type = 'builtin' WHERE code IN :codes"
        ).bindparams(sa.bindparam("codes", expanding=True)),
        {"codes": list(BUILTIN_ROLE_CODES)},
    )

    op.add_column(
        "sys_user",
        sa.Column(
            "is_deleted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column("sys_user", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("sys_user", sa.Column("stage_id", sa.Integer(), nullable=True))
    op.add_column("sys_user", sa.Column("remark", sa.String(length=255), nullable=True))
    op.add_column(
        "sys_user",
        sa.Column(
            "must_change_password",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column("sys_user", sa.Column("password_changed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("sys_user", sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("sys_user", sa.Column("last_login_ip", sa.String(length=64), nullable=True))
    op.add_column("sys_user", sa.Column("last_login_terminal", sa.String(length=255), nullable=True))
    op.create_index(op.f("ix_sys_user_is_deleted"), "sys_user", ["is_deleted"], unique=False)
    op.create_index(op.f("ix_sys_user_stage_id"), "sys_user", ["stage_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_sys_user_stage_id_mes_process_stage"),
        "sys_user",
        "mes_process_stage",
        ["stage_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.add_column(
        "sys_registration_request",
        sa.Column(
            "status",
            sa.String(length=32),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
    )
    op.add_column("sys_registration_request", sa.Column("rejected_reason", sa.Text(), nullable=True))
    op.add_column("sys_registration_request", sa.Column("reviewed_by_user_id", sa.Integer(), nullable=True))
    op.add_column("sys_registration_request", sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index(
        op.f("ix_sys_registration_request_status"),
        "sys_registration_request",
        ["status"],
        unique=False,
    )
    op.create_index(
        op.f("ix_sys_registration_request_reviewed_by_user_id"),
        "sys_registration_request",
        ["reviewed_by_user_id"],
        unique=False,
    )
    op.create_foreign_key(
        op.f("fk_sys_registration_request_reviewed_by_user_id_sys_user"),
        "sys_registration_request",
        "sys_user",
        ["reviewed_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.drop_constraint(
        op.f("uq_sys_registration_request_account"),
        "sys_registration_request",
        type_="unique",
    )
    op.drop_index(op.f("ix_sys_registration_request_account"), table_name="sys_registration_request")
    op.create_index(
        op.f("ix_sys_registration_request_account"),
        "sys_registration_request",
        ["account"],
        unique=False,
    )

    op.create_table(
        "sys_audit_log",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("operator_user_id", sa.Integer(), nullable=True),
        sa.Column("operator_username", sa.String(length=64), nullable=True),
        sa.Column("action_code", sa.String(length=64), nullable=False),
        sa.Column("action_name", sa.String(length=128), nullable=False),
        sa.Column("target_type", sa.String(length=64), nullable=False),
        sa.Column("target_id", sa.String(length=64), nullable=True),
        sa.Column("target_name", sa.String(length=128), nullable=True),
        sa.Column("result", sa.String(length=32), nullable=False),
        sa.Column("before_data", sa.JSON(), nullable=True),
        sa.Column("after_data", sa.JSON(), nullable=True),
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("terminal_info", sa.String(length=255), nullable=True),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(
            ["operator_user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_audit_log_operator_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_audit_log")),
    )
    op.create_index(op.f("ix_sys_audit_log_id"), "sys_audit_log", ["id"], unique=False)
    op.create_index(op.f("ix_sys_audit_log_occurred_at"), "sys_audit_log", ["occurred_at"], unique=False)
    op.create_index(op.f("ix_sys_audit_log_operator_user_id"), "sys_audit_log", ["operator_user_id"], unique=False)
    op.create_index(op.f("ix_sys_audit_log_action_code"), "sys_audit_log", ["action_code"], unique=False)
    op.create_index(op.f("ix_sys_audit_log_target_type"), "sys_audit_log", ["target_type"], unique=False)

    op.create_table(
        "sys_user_session",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("session_token_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False, server_default=sa.text("'active'")),
        sa.Column("is_forced_offline", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("login_time", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_active_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("logout_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("login_ip", sa.String(length=64), nullable=True),
        sa.Column("terminal_info", sa.String(length=255), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_user_session_user_id_sys_user"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_user_session")),
    )
    op.create_index(op.f("ix_sys_user_session_id"), "sys_user_session", ["id"], unique=False)
    op.create_index(
        op.f("ix_sys_user_session_session_token_id"),
        "sys_user_session",
        ["session_token_id"],
        unique=True,
    )
    op.create_index(op.f("ix_sys_user_session_user_id"), "sys_user_session", ["user_id"], unique=False)
    op.create_index(op.f("ix_sys_user_session_status"), "sys_user_session", ["status"], unique=False)
    op.create_index(op.f("ix_sys_user_session_login_time"), "sys_user_session", ["login_time"], unique=False)
    op.create_index(
        op.f("ix_sys_user_session_last_active_at"),
        "sys_user_session",
        ["last_active_at"],
        unique=False,
    )
    op.create_index(op.f("ix_sys_user_session_expires_at"), "sys_user_session", ["expires_at"], unique=False)
    op.create_index(op.f("ix_sys_user_session_logout_time"), "sys_user_session", ["logout_time"], unique=False)

    op.create_table(
        "sys_login_log",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("login_time", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("username", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("success", sa.Boolean(), nullable=False),
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("terminal_info", sa.String(length=255), nullable=True),
        sa.Column("failure_reason", sa.Text(), nullable=True),
        sa.Column("session_token_id", sa.String(length=64), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["sys_user.id"],
            name=op.f("fk_sys_login_log_user_id_sys_user"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sys_login_log")),
    )
    op.create_index(op.f("ix_sys_login_log_id"), "sys_login_log", ["id"], unique=False)
    op.create_index(op.f("ix_sys_login_log_login_time"), "sys_login_log", ["login_time"], unique=False)
    op.create_index(op.f("ix_sys_login_log_username"), "sys_login_log", ["username"], unique=False)
    op.create_index(op.f("ix_sys_login_log_user_id"), "sys_login_log", ["user_id"], unique=False)
    op.create_index(op.f("ix_sys_login_log_success"), "sys_login_log", ["success"], unique=False)
    op.create_index(
        op.f("ix_sys_login_log_session_token_id"),
        "sys_login_log",
        ["session_token_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f("ix_sys_login_log_session_token_id"), table_name="sys_login_log")
    op.drop_index(op.f("ix_sys_login_log_success"), table_name="sys_login_log")
    op.drop_index(op.f("ix_sys_login_log_user_id"), table_name="sys_login_log")
    op.drop_index(op.f("ix_sys_login_log_username"), table_name="sys_login_log")
    op.drop_index(op.f("ix_sys_login_log_login_time"), table_name="sys_login_log")
    op.drop_index(op.f("ix_sys_login_log_id"), table_name="sys_login_log")
    op.drop_table("sys_login_log")

    op.drop_index(op.f("ix_sys_user_session_logout_time"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_expires_at"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_last_active_at"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_login_time"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_status"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_user_id"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_session_token_id"), table_name="sys_user_session")
    op.drop_index(op.f("ix_sys_user_session_id"), table_name="sys_user_session")
    op.drop_table("sys_user_session")

    op.drop_index(op.f("ix_sys_audit_log_target_type"), table_name="sys_audit_log")
    op.drop_index(op.f("ix_sys_audit_log_action_code"), table_name="sys_audit_log")
    op.drop_index(op.f("ix_sys_audit_log_operator_user_id"), table_name="sys_audit_log")
    op.drop_index(op.f("ix_sys_audit_log_occurred_at"), table_name="sys_audit_log")
    op.drop_index(op.f("ix_sys_audit_log_id"), table_name="sys_audit_log")
    op.drop_table("sys_audit_log")

    op.drop_index(op.f("ix_sys_registration_request_account"), table_name="sys_registration_request")
    op.create_index(
        op.f("ix_sys_registration_request_account"),
        "sys_registration_request",
        ["account"],
        unique=True,
    )
    op.create_unique_constraint(
        op.f("uq_sys_registration_request_account"),
        "sys_registration_request",
        ["account"],
    )
    op.drop_constraint(
        op.f("fk_sys_registration_request_reviewed_by_user_id_sys_user"),
        "sys_registration_request",
        type_="foreignkey",
    )
    op.drop_index(op.f("ix_sys_registration_request_reviewed_by_user_id"), table_name="sys_registration_request")
    op.drop_index(op.f("ix_sys_registration_request_status"), table_name="sys_registration_request")
    op.drop_column("sys_registration_request", "reviewed_at")
    op.drop_column("sys_registration_request", "reviewed_by_user_id")
    op.drop_column("sys_registration_request", "rejected_reason")
    op.drop_column("sys_registration_request", "status")

    op.drop_constraint(op.f("fk_sys_user_stage_id_mes_process_stage"), "sys_user", type_="foreignkey")
    op.drop_index(op.f("ix_sys_user_stage_id"), table_name="sys_user")
    op.drop_index(op.f("ix_sys_user_is_deleted"), table_name="sys_user")
    op.drop_column("sys_user", "last_login_terminal")
    op.drop_column("sys_user", "last_login_ip")
    op.drop_column("sys_user", "last_login_at")
    op.drop_column("sys_user", "password_changed_at")
    op.drop_column("sys_user", "must_change_password")
    op.drop_column("sys_user", "remark")
    op.drop_column("sys_user", "stage_id")
    op.drop_column("sys_user", "deleted_at")
    op.drop_column("sys_user", "is_deleted")

    op.drop_index(op.f("ix_sys_role_is_enabled"), table_name="sys_role")
    op.drop_index(op.f("ix_sys_role_is_builtin"), table_name="sys_role")
    op.drop_index(op.f("ix_sys_role_role_type"), table_name="sys_role")
    op.drop_column("sys_role", "is_enabled")
    op.drop_column("sys_role", "is_builtin")
    op.drop_column("sys_role", "role_type")
    op.drop_column("sys_role", "description")
