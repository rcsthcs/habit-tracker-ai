"""
Chatbot — основной модуль чат-бота.
Комбинирует intent parsing (быстрые ответы) + LLM (свободный диалог).
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import date, timedelta
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.chat_message import ChatMessage
from app.nlp.llm_provider import get_llm_provider, LLMProvider
from app.nlp.intent_parser import parse_intent, Intent
from app.nlp.prompts import build_system_prompt, build_motivation_message
from app.ml.pattern_analyzer import PatternAnalyzer
from app.ml.recommender import HabitRecommender
from app.api.routes.habits import _compute_streak, _completion_rate


class HabitChatbot:

    def __init__(self):
        self.llm: LLMProvider = get_llm_provider()
        self.analyzer = PatternAnalyzer()

    async def _build_user_context(self, db: AsyncSession, user: User) -> dict:
        """Gather all user data for context injection into prompts."""
        # Habits with stats
        result = await db.execute(
            select(Habit).where(Habit.user_id == user.id, Habit.is_active == True)
        )
        habits = result.scalars().all()

        habits_data = []
        for h in habits:
            streak = await _compute_streak(db, h.id)
            rate = await _completion_rate(db, h.id)
            habits_data.append({
                "name": h.name,
                "category": h.category,
                "streak": streak,
                "rate": rate,
            })

        # Analytics summary
        today = date.today()
        result = await db.execute(
            select(HabitLog).where(
                HabitLog.habit_id.in_([h.id for h in habits]),
                HabitLog.date == today,
            )
        )
        today_logs = result.scalars().all()
        today_done = sum(1 for l in today_logs if l.completed)

        # Pattern analysis
        df = await self.analyzer.get_logs_dataframe(db, user.id)
        dangers = self.analyzer.find_danger_periods(df) if not df.empty else []

        # Recommendations
        recommendations = await HabitRecommender.get_rule_based_recommendations(db, user.id)

        all_rates = [h["rate"] for h in habits_data]
        overall_rate = round(sum(all_rates) / len(all_rates), 1) if all_rates else 0

        return {
            "username": user.username,
            "habits": habits_data,
            "analytics": {
                "total": len(habits),
                "active": len(habits),
                "today_done": today_done,
                "today_total": len(habits),
                "overall_rate": overall_rate,
                "best_streak": max((h["streak"] for h in habits_data), default=0),
                "optimal_time": self.analyzer.find_optimal_time(df).get("optimal_hour") if not df.empty else None,
            },
            "dangers": dangers,
            "recommendations": recommendations,
        }

    async def _get_chat_history(self, db: AsyncSession, user_id: int, limit: int = 10) -> list[dict]:
        """Get recent chat history for context."""
        result = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.user_id == user_id)
            .order_by(ChatMessage.timestamp.desc())
            .limit(limit)
        )
        messages = result.scalars().all()
        messages.reverse()  # Oldest first
        return [{"role": m.role, "content": m.content} for m in messages]

    async def _handle_quick_intent(self, intent: Intent, entities: dict,
                                    db: AsyncSession, user: User) -> str | None:
        """Handle intents that don't need LLM."""
        if intent == Intent.GREETING:
            # Check if user has streaks to celebrate
            result = await db.execute(
                select(Habit).where(Habit.user_id == user.id, Habit.is_active == True)
            )
            habits = result.scalars().all()
            greeting = f"Привет, {user.username}! 👋\n"

            if habits:
                best_streak = 0
                best_habit = ""
                for h in habits:
                    s = await _compute_streak(db, h.id)
                    if s > best_streak:
                        best_streak = s
                        best_habit = h.name

                if best_streak > 0:
                    greeting += build_motivation_message(best_streak, best_habit)
                else:
                    greeting += "Готов покорять привычки сегодня? 💪"
            else:
                greeting += "Добавь свою первую привычку и начни путь к лучшей версии себя! 🚀"
            return greeting

        if intent == Intent.HELP:
            return ("Вот что я умею:\n"
                    "📊 **Статистика** — расскажу о твоём прогрессе\n"
                    "💡 **Советы** — дам персональные рекомендации\n"
                    "💪 **Мотивация** — поддержу в трудный момент\n"
                    "🆕 **Новые привычки** — предложу что добавить\n"
                    "💬 **Свободный диалог** — просто поболтаем о привычках!")

        if intent == Intent.SHOW_STATS:
            result = await db.execute(
                select(Habit).where(Habit.user_id == user.id, Habit.is_active == True)
            )
            habits = result.scalars().all()
            if not habits:
                return "У тебя пока нет привычек. Добавь первую! ➕"

            text = "📊 **Твоя статистика:**\n"
            for h in habits:
                streak = await _compute_streak(db, h.id)
                rate = await _completion_rate(db, h.id)
                emoji = "🔥" if streak >= 7 else ("✅" if streak >= 3 else "📌")
                text += f"{emoji} {h.name}: серия {streak} дней, выполнение {rate}%\n"
            return text

        return None  # Intent not handled quickly → go to LLM

    async def process_message(self, db: AsyncSession, user: User, message: str) -> str:
        """Main entry point: process user message and return response."""
        # 1. Parse intent
        parsed = parse_intent(message)

        # 2. Try quick response
        quick_response = await self._handle_quick_intent(parsed.intent, parsed.entities, db, user)
        if quick_response:
            return quick_response

        # 3. For complex intents or free chat → use LLM
        user_context = await self._build_user_context(db, user)
        system_prompt = build_system_prompt(user_context)
        history = await self._get_chat_history(db, user.id)

        response = await self.llm.generate(system_prompt, message, history)
        return response

