from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class FirstArticleParticipant(Base):
    __tablename__ = "mes_first_article_participant"

    record_id: Mapped[int] = mapped_column(
        ForeignKey("mes_first_article_record.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("sys_user.id", ondelete="RESTRICT"),
        primary_key=True,
        index=True,
    )

    record = relationship("FirstArticleRecord", back_populates="participants")
    user = relationship("User")
