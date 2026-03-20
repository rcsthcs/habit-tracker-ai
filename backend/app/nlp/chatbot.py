"""
Chatbot — основной модуль чат-бота.
Комбинирует intent parsing (быстрые ответы) + LLM (свободный диалог).
"""
import json
import re
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import date, timedelta, datetime, timezone
from app.models.user import User
from app.models.habit import Habit
from app.models.habit_log import HabitLog
from app.models.chat_message import ChatMessage
from app.models.mood_log import MoodLog
from app.models.user_activity import UserActivity
from app.models.challenge import Challenge, ChallengeStatus
from app.models.achievement import Achievement, ACHIEVEMENT_META
from app.nlp.llm_provider import get_llm_provider, LLMProvider, FallbackProvider
from app.nlp.intent_parser import parse_intent, Intent
from app.nlp.prompts import build_system_prompt, build_motivation_message
from app.ml.pattern_analyzer import PatternAnalyzer
from app.ml.recommender import HabitRecommender
from app.api.routes.habits import _compute_streak, _completion_rate


class HabitChatbot:

    def __init__(self):
        self.llm: LLMProvider = get_llm_provider()
        self.analyzer = PatternAnalyzer()

    _supported_categories = {
        "health",
        "fitness",
        "nutrition",
        "mindfulness",
        "productivity",
        "learning",
        "social",
        "sleep",
        "finance",
        "other",
    }

    _category_aliases = {
        "sleep": "sleep",
        "сон": "sleep",
        "здоровье": "health",
        "health": "health",
        "фитнес": "fitness",
        "fitness": "fitness",
        "nutrition": "nutrition",
        "питание": "nutrition",
        "mindfulness": "mindfulness",
        "осознанность": "mindfulness",
        "productivity": "productivity",
        "продуктивность": "productivity",
        "learning": "learning",
        "обучение": "learning",
        "social": "social",
        "социальное": "social",
        "finance": "finance",
        "финансы": "finance",
        "other": "other",
        "другое": "other",
    }

    _invalid_habit_prefixes = (
        "категория:",
        "микро-шаг:",
        "привязка:",
        "совет:",
        "шаг ",
    )

    def _build_memory_summary(self, history: list[dict]) -> dict:
        user_messages = [m for m in history if m.get("role") == "user"]
        assistant_messages = [m for m in history if m.get("role") == "assistant"]

        recent_user_topics = []
        for item in user_messages[-3:]:
            content = (item.get("content") or "").replace("\n", " ").strip()
            if content:
                recent_user_topics.append(content[:90])

        return {
            "total_messages": len(history),
            "user_messages": len(user_messages),
            "assistant_messages": len(assistant_messages),
            "recent_user_topics": recent_user_topics,
        }

    async def _build_user_context(
        self,
        db: AsyncSession,
        user: User,
        history: list[dict],
        context_hints: dict | None = None,
    ) -> dict:
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
        today_logs = []
        if habits:
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

        mood_result = await db.execute(
            select(MoodLog)
            .where(
                MoodLog.user_id == user.id,
                MoodLog.date >= today - timedelta(days=14),
            )
            .order_by(MoodLog.date.desc())
        )
        mood_logs = mood_result.scalars().all()
        mood_scores = [m.score for m in mood_logs]

        mood_trend = "stable"
        if len(mood_logs) >= 6:
            half = len(mood_logs) // 2
            recent = mood_scores[:half]
            older = mood_scores[half:]
            if recent and older:
                diff = (sum(recent) / len(recent)) - (sum(older) / len(older))
                if diff > 0.3:
                    mood_trend = "improving"
                elif diff < -0.3:
                    mood_trend = "declining"

        mood_context = {
            "last_score": mood_logs[0].score if mood_logs else None,
            "avg_7d": round(
                sum(m.score for m in mood_logs if m.date >= today - timedelta(days=7))
                / max(1, len([m for m in mood_logs if m.date >= today - timedelta(days=7)])),
                2,
            ) if mood_logs else None,
            "trend": mood_trend,
            "recent": [
                {
                    "date": m.date.isoformat(),
                    "score": m.score,
                    "energy": m.energy_level,
                    "stress": m.stress_level,
                    "tags": m.tags,
                }
                for m in mood_logs[:5]
            ],
        }

        achievements_result = await db.execute(
            select(Achievement)
            .where(Achievement.user_id == user.id)
            .order_by(Achievement.unlocked_at.desc())
            .limit(5)
        )
        achievements = achievements_result.scalars().all()
        achievements_data = [
            {
                "type": a.achievement_type,
                "title": ACHIEVEMENT_META.get(a.achievement_type, {}).get("title", a.achievement_type),
                "unlocked_at": a.unlocked_at.isoformat(),
            }
            for a in achievements
        ]

        challenges_result = await db.execute(
            select(Challenge)
            .where(
                Challenge.user_id == user.id,
                Challenge.status == ChallengeStatus.ACTIVE,
                Challenge.end_date >= today,
            )
            .order_by(Challenge.end_date.asc())
            .limit(5)
        )
        challenges = challenges_result.scalars().all()
        challenges_data = [
            {
                "title": c.title,
                "type": str(c.type),
                "progress": f"{c.current_count}/{c.target_count}",
                "end_date": c.end_date.isoformat(),
            }
            for c in challenges
        ]

        activity_since = datetime.now(timezone.utc) - timedelta(days=7)
        activity_result = await db.execute(
            select(UserActivity)
            .where(
                UserActivity.user_id == user.id,
                UserActivity.session_start >= activity_since,
            )
            .order_by(UserActivity.session_start.desc())
            .limit(100)
        )
        activities = activity_result.scalars().all()
        screens = [a.screen for a in activities if a.screen]
        unique_screens = sorted(set(screens))[:5]

        memory_summary = self._build_memory_summary(history)

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
            "mood": mood_context,
            "achievements": achievements_data,
            "challenges": challenges_data,
            "activity": {
                "sessions_7d": len(activities),
                "screens": unique_screens,
            },
            "memory": memory_summary,
            "client_hints": context_hints or {},
        }

    async def _get_chat_history(
        self,
        db: AsyncSession,
        user_id: int,
        session_id: str,
        limit: int = 10,
    ) -> list[dict]:
        """Get recent chat history for context."""
        result = await db.execute(
            select(ChatMessage)
            .where(
                ChatMessage.user_id == user_id,
                ChatMessage.session_id == session_id,
            )
            .order_by(ChatMessage.timestamp.desc())
            .limit(limit)
        )
        messages = result.scalars().all()
        messages.reverse()  # Oldest first
        return [{"role": m.role, "content": m.content} for m in messages]

    def _normalize_category(self, value: str | None) -> str:
        normalized = (value or "other").strip().lower()
        return self._category_aliases.get(normalized, "other")

    def _normalize_frequency(self, value: str | None) -> tuple[str, int]:
        normalized = (value or "Каждый день").strip().lower()
        if "через" in normalized and "день" in normalized:
            return "Через день", 2
        if "3" in normalized:
            return "Раз в 3 дня", 3
        if "недел" in normalized:
            return "Раз в неделю", 7
        return "Каждый день", 1

    def _normalize_time_of_day(
        self,
        value: str | None,
    ) -> tuple[str | None, str | None, str | None]:
        normalized = (value or "Any").strip().lower()
        if normalized in {"morning", "утро", "утром"}:
            return "Morning", "08:00", "07:30"
        if normalized in {"day", "afternoon", "день", "днём", "днем"}:
            return "Day", "13:00", "12:30"
        if normalized in {"evening", "вечер", "вечером"}:
            return "Evening", "20:30", "20:00"
        return "Any", None, None

    def _default_folder_name(self, category: str) -> str | None:
        if category == "sleep":
            return "Улучшение сна"
        if category in {"fitness", "health", "nutrition"}:
            return "Здоровый ритм"
        if category in {"learning", "productivity"}:
            return "Фокус и рост"
        return None

    def _sanitize_habit_title(self, value: str | None) -> str:
        title = re.sub(r"\s+", " ", (value or "").strip())
        return title.strip("-•* ")

    def _build_structured_habit(
        self,
        title: str,
        description: str,
        category: str,
        frequency: str,
        time_of_day: str | None,
    ) -> dict:
        normalized_category = self._normalize_category(category)
        normalized_frequency, cooldown_days = self._normalize_frequency(frequency)
        normalized_tod, target_time, reminder_time = self._normalize_time_of_day(time_of_day)
        return {
            "title": title,
            "description": description,
            "category": normalized_category,
            "frequency": normalized_frequency,
            "time_of_day": normalized_tod,
            "reason": description,
            "cooldown_days": cooldown_days,
            "daily_target": 1,
            "target_time": target_time,
            "reminder_time": reminder_time,
            "group_name": self._default_folder_name(normalized_category),
        }

    def _parse_llm_response(
        self,
        raw_response: str,
        fallback_recommendations: list[dict],
        should_include_habits: bool,
    ) -> dict:
        cleaned = (raw_response or "").strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        if cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

        payload = None
        try:
            payload = json.loads(cleaned)
        except Exception:
            start = cleaned.find("{")
            end = cleaned.rfind("}")
            if start >= 0 and end > start:
                try:
                    payload = json.loads(cleaned[start:end + 1])
                except Exception:
                    payload = None

        if not isinstance(payload, dict):
            payload = {"message": raw_response.strip(), "habits": []}

        message = (payload.get("message") or raw_response or "").strip()
        category = self._normalize_category(payload.get("category"))
        folder_name = (payload.get("folderName") or payload.get("folder_name") or "").strip() or None

        habits = []
        raw_habits = payload.get("habits") or []
        if isinstance(raw_habits, list):
            for item in raw_habits:
                if not isinstance(item, dict):
                    continue
                title = self._sanitize_habit_title(item.get("title"))
                if not title:
                    continue
                lower_title = title.lower()
                if any(lower_title.startswith(prefix) for prefix in self._invalid_habit_prefixes):
                    continue
                description = (item.get("description") or "").strip()
                if not description:
                    description = "Полезная привычка от AI-ассистента"
                habits.append(
                    self._build_structured_habit(
                        title=title,
                        description=description,
                        category=item.get("category") or category,
                        frequency=item.get("frequency") or "Каждый день",
                        time_of_day=item.get("timeOfDay") or item.get("time_of_day"),
                    )
                )
                if len(habits) >= 3:
                    break

        if should_include_habits and not habits:
            for recommendation in fallback_recommendations[:3]:
                title = self._sanitize_habit_title(recommendation.get("title"))
                if not title:
                    continue
                rec_category = self._normalize_category(recommendation.get("category"))
                habits.append(
                    self._build_structured_habit(
                        title=title,
                        description=(recommendation.get("reason") or recommendation.get("description") or "Полезная привычка"),
                        category=rec_category,
                        frequency="Каждый день",
                        time_of_day="Evening" if rec_category == "sleep" else "Any",
                    )
                )
            if habits and folder_name is None:
                folder_name = self._default_folder_name(habits[0]["category"])
            if habits:
                category = habits[0]["category"]

        return {
            "message": message,
            "category": category if habits else None,
            "folder_name": folder_name if habits else None,
            "habits": habits,
        }

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

    async def process_message(
        self,
        db: AsyncSession,
        user: User,
        session_id: str,
        message: str,
        context_hints: dict | None = None,
    ) -> dict:
        """Main entry point: process user message and return structured response."""
        # 1. Parse intent
        parsed = parse_intent(message)

        # 2. Try quick response
        quick_response = await self._handle_quick_intent(parsed.intent, parsed.entities, db, user)
        if quick_response:
            return {
                "message": quick_response,
                "category": None,
                "folder_name": None,
                "habits": [],
            }

        # 3. For complex intents or free chat → use LLM
        history = await self._get_chat_history(db, user.id, session_id)
        user_context = await self._build_user_context(
            db,
            user,
            history=history,
            context_hints=context_hints,
        )
        system_prompt = build_system_prompt(user_context)

        response = await self.llm.generate(system_prompt, message, history)
        normalized_response = (response or "").lower()
        if (
            "не могу ответить" in normalized_response
            and "недоступен" in normalized_response
        ) or "api ключ не настроен" in normalized_response:
            fallback = FallbackProvider()
            response = await fallback.generate(system_prompt, message, history)
        should_include_habits = parsed.intent in {
            Intent.ADD_HABIT,
            Intent.GET_ADVICE,
        }
        return self._parse_llm_response(
            response,
            fallback_recommendations=user_context.get("recommendations", []),
            should_include_habits=should_include_habits,
        )

