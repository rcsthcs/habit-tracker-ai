"""
Recommender — рекомендации новых привычек.
Два слоя:
1. Rule-based ассоциации категорий (работает сразу)
2. Коллаборативная фильтрация (включается при достаточном количестве пользователей)
"""
import numpy as np
from collections import defaultdict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.habit import Habit, HabitCategory
from app.models.habit_log import HabitLog
from app.config import get_settings


# Rule-based category associations: if user has habit in key, suggest from value
CATEGORY_ASSOCIATIONS = {
    HabitCategory.FITNESS: [
        {"category": HabitCategory.NUTRITION, "name": "Правильное питание",
         "reason": "Питание дополняет физическую активность для лучших результатов"},
        {"category": HabitCategory.SLEEP, "name": "Режим сна",
         "reason": "Хороший сон помогает восстановлению после тренировок"},
    ],
    HabitCategory.NUTRITION: [
        {"category": HabitCategory.FITNESS, "name": "Утренняя зарядка",
         "reason": "Физическая активность усиливает эффект здорового питания"},
        {"category": HabitCategory.HEALTH, "name": "Пить воду",
         "reason": "Гидратация — важная часть правильного питания"},
    ],
    HabitCategory.MINDFULNESS: [
        {"category": HabitCategory.SLEEP, "name": "Вечерняя медитация перед сном",
         "reason": "Медитация улучшает качество сна"},
        {"category": HabitCategory.HEALTH, "name": "Дыхательные упражнения",
         "reason": "Дыхательные практики дополняют осознанность"},
    ],
    HabitCategory.PRODUCTIVITY: [
        {"category": HabitCategory.LEARNING, "name": "Чтение 20 минут",
         "reason": "Чтение повышает продуктивность и расширяет кругозор"},
        {"category": HabitCategory.MINDFULNESS, "name": "Утренняя медитация",
         "reason": "Медитация помогает фокусироваться и быть продуктивнее"},
    ],
    HabitCategory.LEARNING: [
        {"category": HabitCategory.PRODUCTIVITY, "name": "Планирование дня",
         "reason": "Планирование помогает выделять время на обучение"},
    ],
    HabitCategory.SLEEP: [
        {"category": HabitCategory.MINDFULNESS, "name": "Медитация",
         "reason": "Медитация улучшает засыпание"},
        {"category": HabitCategory.FITNESS, "name": "Вечерняя прогулка",
         "reason": "Лёгкая активность вечером способствует здоровому сну"},
    ],
    HabitCategory.HEALTH: [
        {"category": HabitCategory.FITNESS, "name": "30 минут ходьбы",
         "reason": "Ходьба — простой способ поддержать здоровье"},
        {"category": HabitCategory.NUTRITION, "name": "Завтрак без сахара",
         "reason": "Правильный завтрак — основа здоровья"},
    ],
    HabitCategory.SOCIAL: [
        {"category": HabitCategory.MINDFULNESS, "name": "Благодарность",
         "reason": "Практика благодарности улучшает социальные отношения"},
    ],
    HabitCategory.FINANCE: [
        {"category": HabitCategory.PRODUCTIVITY, "name": "Учёт расходов",
         "reason": "Системный подход к финансам повышает контроль"},
    ],
}


class HabitRecommender:

    @staticmethod
    async def get_rule_based_recommendations(
        db: AsyncSession, user_id: int
    ) -> list[dict]:
        """Get recommendations based on category associations."""
        result = await db.execute(
            select(Habit).where(Habit.user_id == user_id, Habit.is_active == True)
        )
        user_habits = result.scalars().all()
        if not user_habits:
            return [{
                "type": "new_habit",
                "title": "Начни с малого!",
                "description": "Попробуй добавить одну простую привычку, например 'Пить воду' или 'Утренняя зарядка'",
                "reason": "Маленькие привычки легче закрепить",
            }]

        user_categories = {h.category for h in user_habits}
        user_habit_names = {h.name.lower() for h in user_habits}
        recommendations = []

        for category in user_categories:
            if category in CATEGORY_ASSOCIATIONS:
                for suggestion in CATEGORY_ASSOCIATIONS[category]:
                    # Don't suggest what user already has
                    if (suggestion["category"] not in user_categories
                            and suggestion["name"].lower() not in user_habit_names):
                        recommendations.append({
                            "type": "new_habit",
                            "title": suggestion["name"],
                            "description": f"Категория: {suggestion['category'].value}",
                            "reason": suggestion["reason"],
                            "category": suggestion["category"].value,
                        })

        # Deduplicate by title
        seen = set()
        unique = []
        for rec in recommendations:
            if rec["title"] not in seen:
                seen.add(rec["title"])
                unique.append(rec)

        return unique[:5]  # Top 5 recommendations

    @staticmethod
    async def get_collaborative_recommendations(
        db: AsyncSession, user_id: int
    ) -> list[dict]:
        """
        Collaborative filtering: find similar users and suggest their habits.
        Only activated when there are enough users in the system.
        """
        settings = get_settings()

        # Get all users' habit vectors
        result = await db.execute(select(Habit).where(Habit.is_active == True))
        all_habits = result.scalars().all()

        # Group habits by user
        user_habits: dict[int, set[str]] = defaultdict(set)
        for habit in all_habits:
            user_habits[habit.user_id].add(habit.category)

        if len(user_habits) < settings.MIN_USERS_FOR_COLLAB:
            return []  # Not enough users

        # Build category vector for each user
        all_categories = list(HabitCategory)
        vectors = {}
        for uid, categories in user_habits.items():
            vector = [1.0 if cat in categories else 0.0 for cat in all_categories]
            vectors[uid] = np.array(vector)

        if user_id not in vectors:
            return []

        # Find most similar users (cosine similarity)
        user_vec = vectors[user_id]
        similarities = []
        for uid, vec in vectors.items():
            if uid != user_id:
                dot = np.dot(user_vec, vec)
                norm = np.linalg.norm(user_vec) * np.linalg.norm(vec)
                sim = dot / norm if norm > 0 else 0
                similarities.append((uid, sim))

        similarities.sort(key=lambda x: x[1], reverse=True)
        top_similar = similarities[:3]

        # Suggest habits from similar users that current user doesn't have
        current_categories = user_habits[user_id]
        suggestions = []
        for similar_uid, sim_score in top_similar:
            if sim_score < 0.3:
                continue
            diff_categories = user_habits[similar_uid] - current_categories
            for cat in diff_categories:
                # Find actual habit names from similar user
                for habit in all_habits:
                    if habit.user_id == similar_uid and habit.category == cat:
                        suggestions.append({
                            "type": "collaborative",
                            "title": habit.name,
                            "description": f"Категория: {cat}",
                            "reason": f"Похожие пользователи также практикуют эту привычку",
                            "category": cat,
                        })

        return suggestions[:3]

