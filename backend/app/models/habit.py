from datetime import datetime, timezone
from sqlalchemy import Integer, String, DateTime, Boolean, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base
import enum


class HabitCategory(str, enum.Enum):
    HEALTH = "health"
    FITNESS = "fitness"
    NUTRITION = "nutrition"
    MINDFULNESS = "mindfulness"
    PRODUCTIVITY = "productivity"
    LEARNING = "learning"
    SOCIAL = "social"
    SLEEP = "sleep"
    FINANCE = "finance"
    OTHER = "other"


class HabitFrequency(str, enum.Enum):
    DAILY = "daily"
    WEEKDAYS = "weekdays"
    WEEKENDS = "weekends"
    WEEKLY = "weekly"
    CUSTOM = "custom"


# Рекомендации названий привычек по категориям
HABIT_NAME_SUGGESTIONS: dict[str, list[str]] = {
    "health": ["Выпить 2л воды", "Принять витамины", "Измерить давление", "Посетить врача"],
    "fitness": ["Утренняя зарядка 15 мин", "Пробежка 3 км", "30 отжиманий", "Растяжка 10 мин"],
    "nutrition": ["Завтрак без сахара", "5 порций овощей", "Не есть после 20:00", "Готовить дома"],
    "mindfulness": ["Медитация 10 мин", "Дневник благодарности", "Дыхательная практика", "Цифровой детокс 1ч"],
    "productivity": ["Планировать день утром", "Техника Помодоро", "Убрать рабочее место", "Без соцсетей до обеда"],
    "learning": ["Читать 30 мин", "Учить 10 новых слов", "Онлайн-курс 20 мин", "Написать конспект"],
    "social": ["Позвонить другу", "Комплимент коллеге", "Семейный ужин", "Написать письмо"],
    "sleep": ["Лечь до 23:00", "Без экранов за 1ч до сна", "Проветрить комнату", "Режим сна 8ч"],
    "finance": ["Записать расходы", "Отложить 500₽", "Не покупать импульсивно", "Проверить подписки"],
    "other": ["Выгулять собаку", "Полить цветы", "Уборка 15 мин", "Новое хобби 30 мин"],
}


class Habit(Base):
    __tablename__ = "habits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(500), default="")
    category: Mapped[str] = mapped_column(
        SAEnum(HabitCategory), default=HabitCategory.OTHER
    )
    frequency: Mapped[str] = mapped_column(
        SAEnum(HabitFrequency), default=HabitFrequency.DAILY
    )
    cooldown_days: Mapped[int] = mapped_column(Integer, default=1)  # 1=каждый день, 2=через день, и т.д.
    target_time: Mapped[str] = mapped_column(String(5), nullable=True)  # HH:MM — когда выполнять
    reminder_time: Mapped[str] = mapped_column(String(5), nullable=True)  # HH:MM — когда push-напоминание
    color: Mapped[str] = mapped_column(String(7), default="#4CAF50")
    icon: Mapped[str] = mapped_column(String(50), default="check_circle")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    # Relationships
    user = relationship("User", back_populates="habits")
    logs = relationship("HabitLog", back_populates="habit", cascade="all, delete-orphan")
