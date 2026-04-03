from sqlalchemy import Boolean, ForeignKey, String, Text, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FirstArticleTemplate(Base, TimestampMixin):
    __tablename__ = "mes_first_article_template"
    __table_args__ = (
        UniqueConstraint(
            "product_id",
            "process_code",
            "template_name",
            name="uq_mes_first_article_template_product_process_name",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("mes_product.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    process_code: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    template_name: Mapped[str] = mapped_column(String(128), nullable=False)
    check_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    test_value: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default=text("true"),
        index=True,
    )

    product = relationship("Product")
