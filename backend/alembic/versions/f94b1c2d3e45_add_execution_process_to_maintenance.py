"""add execution process fields to maintenance plan and work order

Revision ID: f94b1c2d3e45
Revises: e42f8a6c1d73
Create Date: 2026-03-02 12:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f94b1c2d3e45"
down_revision: Union[str, Sequence[str], None] = "e42f8a6c1d73"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "mes_maintenance_plan",
        sa.Column(
            "execution_process_code",
            sa.String(length=64),
            nullable=True,
            server_default=sa.text("'laser_marking'"),
        ),
    )
    op.create_index(
        op.f("ix_mes_maintenance_plan_execution_process_code"),
        "mes_maintenance_plan",
        ["execution_process_code"],
        unique=False,
    )
    op.create_check_constraint(
        "ck_mes_maintenance_plan_execution_process_code_allowed",
        "mes_maintenance_plan",
        "execution_process_code IN ('laser_marking', 'product_testing', 'product_assembly', 'product_packaging')",
    )

    op.execute(
        """
        UPDATE mes_maintenance_plan AS mp
        SET execution_process_code = CASE TRIM(COALESCE(eq.location, ''))
            WHEN '激光打标' THEN 'laser_marking'
            WHEN '产品测试' THEN 'product_testing'
            WHEN '产品组装' THEN 'product_assembly'
            WHEN '产品包装' THEN 'product_packaging'
            ELSE 'laser_marking'
        END
        FROM mes_equipment AS eq
        WHERE mp.equipment_id = eq.id
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_plan
        SET execution_process_code = 'laser_marking'
        WHERE execution_process_code IS NULL OR TRIM(execution_process_code) = ''
        """
    )
    op.alter_column("mes_maintenance_plan", "execution_process_code", nullable=False, server_default=None)

    op.add_column(
        "mes_maintenance_work_order",
        sa.Column(
            "source_execution_process_code",
            sa.String(length=64),
            nullable=True,
            server_default=sa.text("'laser_marking'"),
        ),
    )
    op.create_index(
        op.f("ix_mes_maintenance_work_order_source_execution_process_code"),
        "mes_maintenance_work_order",
        ["source_execution_process_code"],
        unique=False,
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET source_execution_process_code = mp.execution_process_code
        FROM mes_maintenance_plan AS mp
        WHERE wo.plan_id = mp.id
          AND (wo.source_execution_process_code IS NULL OR TRIM(wo.source_execution_process_code) = '')
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order AS wo
        SET source_execution_process_code = CASE TRIM(COALESCE(eq.location, ''))
            WHEN '激光打标' THEN 'laser_marking'
            WHEN '产品测试' THEN 'product_testing'
            WHEN '产品组装' THEN 'product_assembly'
            WHEN '产品包装' THEN 'product_packaging'
            ELSE 'laser_marking'
        END
        FROM mes_equipment AS eq
        WHERE wo.equipment_id = eq.id
          AND (wo.source_execution_process_code IS NULL OR TRIM(wo.source_execution_process_code) = '')
        """
    )
    op.execute(
        """
        UPDATE mes_maintenance_work_order
        SET source_execution_process_code = 'laser_marking'
        WHERE source_execution_process_code IS NULL OR TRIM(source_execution_process_code) = ''
        """
    )
    op.alter_column(
        "mes_maintenance_work_order",
        "source_execution_process_code",
        nullable=False,
        server_default=None,
    )

    op.execute(
        """
        INSERT INTO sys_page_visibility (page_code, role_code, is_visible, created_at, updated_at)
        VALUES ('maintenance_execution', 'quality_admin', TRUE, NOW(), NOW())
        ON CONFLICT (page_code, role_code)
        DO UPDATE SET is_visible = EXCLUDED.is_visible, updated_at = NOW()
        """
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        """
        DELETE FROM sys_page_visibility
        WHERE page_code = 'maintenance_execution' AND role_code = 'quality_admin'
        """
    )

    op.drop_index(
        op.f("ix_mes_maintenance_work_order_source_execution_process_code"),
        table_name="mes_maintenance_work_order",
    )
    op.drop_column("mes_maintenance_work_order", "source_execution_process_code")

    op.drop_constraint(
        "ck_mes_maintenance_plan_execution_process_code_allowed",
        "mes_maintenance_plan",
        type_="check",
    )
    op.drop_index(
        op.f("ix_mes_maintenance_plan_execution_process_code"),
        table_name="mes_maintenance_plan",
    )
    op.drop_column("mes_maintenance_plan", "execution_process_code")
