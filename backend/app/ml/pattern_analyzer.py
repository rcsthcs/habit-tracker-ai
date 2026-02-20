"""
Pattern Analyzer — анализ временных паттернов выполнения привычек.
Определяет оптимальное время, опасные периоды пропусков, прогнозирует вероятность выполнения.
"""
import pandas as pd
import numpy as np
from datetime import date, timedelta, datetime
from collections import Counter
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.habit import Habit
from app.models.habit_log import HabitLog


class PatternAnalyzer:

    @staticmethod
    async def get_logs_dataframe(db: AsyncSession, user_id: int) -> pd.DataFrame:
        """Fetch all habit logs for user and return as DataFrame."""
        result = await db.execute(
            select(HabitLog, Habit.name, Habit.category)
            .join(Habit, HabitLog.habit_id == Habit.id)
            .where(Habit.user_id == user_id)
            .order_by(HabitLog.date.desc())
        )
        rows = result.all()
        if not rows:
            return pd.DataFrame()

        data = []
        for log, habit_name, category in rows:
            data.append({
                "habit_id": log.habit_id,
                "habit_name": habit_name,
                "category": category,
                "date": log.date,
                "completed": log.completed,
                "completed_at": log.completed_at,
                "day_of_week": log.date.weekday(),  # 0=Mon, 6=Sun
                "hour": log.completed_at.hour if log.completed_at else None,
            })
        return pd.DataFrame(data)

    @staticmethod
    def find_optimal_time(df: pd.DataFrame) -> dict:
        """Find optimal hour and day of week for completing habits."""
        if df.empty:
            return {"optimal_hour": None, "optimal_day": None}

        completed = df[df["completed"] == True]
        if completed.empty:
            return {"optimal_hour": None, "optimal_day": None}

        # Best hour
        hours = completed["hour"].dropna()
        optimal_hour = int(hours.mode().iloc[0]) if not hours.empty else None

        # Best day of week
        day_rates = df.groupby("day_of_week")["completed"].mean()
        optimal_day = int(day_rates.idxmax()) if not day_rates.empty else None

        return {"optimal_hour": optimal_hour, "optimal_day": optimal_day}

    @staticmethod
    def find_danger_periods(df: pd.DataFrame) -> list[dict]:
        """Find time periods where user tends to skip habits."""
        if df.empty:
            return []

        dangers = []

        # By day of week
        day_names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
        day_rates = df.groupby("day_of_week")["completed"].mean()
        for day, rate in day_rates.items():
            if rate < 0.5:
                dangers.append({
                    "type": "day_of_week",
                    "period": day_names[day],
                    "completion_rate": round(rate * 100, 1),
                    "message": f"Ты часто пропускаешь привычки в {day_names[day]} (выполнение {round(rate*100)}%)",
                })

        # By hour (morning vs evening)
        completed_with_hour = df[df["hour"].notna()].copy()
        if not completed_with_hour.empty:
            completed_with_hour["period"] = completed_with_hour["hour"].apply(
                lambda h: "утро" if 5 <= h < 12 else ("день" if 12 <= h < 17 else ("вечер" if 17 <= h < 22 else "ночь"))
            )
            period_rates = completed_with_hour.groupby("period")["completed"].mean()
            for period, rate in period_rates.items():
                if rate < 0.5:
                    dangers.append({
                        "type": "time_of_day",
                        "period": period,
                        "completion_rate": round(rate * 100, 1),
                        "message": f"Привычки в {period} выполняются реже ({round(rate*100)}%)",
                    })

        return dangers

    @staticmethod
    def find_struggling_habits(df: pd.DataFrame) -> list[dict]:
        """Find habits that the user struggles with most."""
        if df.empty:
            return []

        habit_rates = df.groupby(["habit_id", "habit_name"])["completed"].agg(["mean", "count"])
        struggling = habit_rates[habit_rates["mean"] < 0.5].sort_values("mean")

        results = []
        for (habit_id, habit_name), row in struggling.iterrows():
            results.append({
                "habit_id": habit_id,
                "habit_name": habit_name,
                "completion_rate": round(row["mean"] * 100, 1),
                "total_logs": int(row["count"]),
            })
        return results

    @staticmethod
    def compute_streak_history(df: pd.DataFrame, habit_id: int) -> dict:
        """Compute streak statistics for a specific habit."""
        habit_df = df[df["habit_id"] == habit_id].sort_values("date")
        if habit_df.empty:
            return {"current_streak": 0, "longest_streak": 0, "avg_streak": 0}

        streaks = []
        current = 0
        for _, row in habit_df.iterrows():
            if row["completed"]:
                current += 1
            else:
                if current > 0:
                    streaks.append(current)
                current = 0
        if current > 0:
            streaks.append(current)

        return {
            "current_streak": streaks[-1] if streaks else 0,
            "longest_streak": max(streaks) if streaks else 0,
            "avg_streak": round(np.mean(streaks), 1) if streaks else 0,
            "total_streaks": len(streaks),
        }

    @staticmethod
    def predict_today_completion(df: pd.DataFrame, habit_id: int) -> float:
        """Simple probability estimate of completing habit today based on historical patterns."""
        today_dow = date.today().weekday()
        habit_df = df[df["habit_id"] == habit_id]
        if habit_df.empty:
            return 0.5  # No data, neutral probability

        # Weight recent data more
        recent = habit_df[habit_df["date"] >= date.today() - timedelta(days=14)]
        same_day = habit_df[habit_df["day_of_week"] == today_dow]

        overall_rate = habit_df["completed"].mean()
        recent_rate = recent["completed"].mean() if not recent.empty else overall_rate
        day_rate = same_day["completed"].mean() if not same_day.empty else overall_rate

        # Weighted average: recent data matters most
        probability = 0.5 * recent_rate + 0.3 * day_rate + 0.2 * overall_rate
        return round(float(probability), 2)

