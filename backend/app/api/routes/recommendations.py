from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.schemas.analytics import RecommendationResponse
from app.api.auth_utils import get_current_user
from app.ml.recommender import HabitRecommender
from app.ml.pattern_analyzer import PatternAnalyzer
from app.ml.classifier import HabitDifficultyClassifier
from app.nlp.prompts import build_motivation_message, build_recovery_message
from app.api.routes.habits import _compute_streak

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/", response_model=RecommendationResponse)
async def get_recommendations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    analyzer = PatternAnalyzer()
    classifier = HabitDifficultyClassifier()
    classifier.load_model()

    # Get log data
    df = await analyzer.get_logs_dataframe(db, current_user.id)

    rule_recs = await HabitRecommender.get_rule_based_recommendations(db, current_user.id)
    collab_recs = await HabitRecommender.get_collaborative_recommendations(db, current_user.id)
    
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    user_habits_for_llm = result.scalars().all()
    llm_recs = await HabitRecommender.get_llm_recommendations(user_habits_for_llm)
    
    all_recommendations = rule_recs + collab_recs + llm_recs

    # Tips from pattern analysis
    tips = []
    if not df.empty:
        dangers = analyzer.find_danger_periods(df)
        for d in dangers:
            tips.append(d["message"])

        optimal = analyzer.find_optimal_time(df)
        if optimal["optimal_hour"] is not None:
            tips.append(f"Твоё самое продуктивное время — {optimal['optimal_hour']:02d}:00. Попробуй планировать привычки на это время!")

        # Difficulty classification
        difficulties = classifier.predict(df)
        hard_habits = [d for d in difficulties if d["difficulty"] == "hard"]
        for h in hard_habits:
            tips.append(f"Привычка '{h['habit_name']}' даётся сложнее всего ({h['completion_rate']}%). Попробуй упростить её или разбить на мелкие шаги.")

        # Train model if enough data
        classifier.train(df)
    else:
        tips.append("Добавь привычки и начни их отмечать — и я смогу давать персонализированные советы!")

    # Motivation message
    result = await db.execute(
        select(Habit).where(Habit.user_id == current_user.id, Habit.is_active == True)
    )
    habits = result.scalars().all()

    motivation = "Начни свой путь к лучшим привычкам! 🚀"
    if habits:
        best_streak = 0
        best_habit_name = ""
        for h in habits:
            s = await _compute_streak(db, h.id)
            if s > best_streak:
                best_streak = s
                best_habit_name = h.name

        if best_streak > 0:
            motivation = build_motivation_message(best_streak, best_habit_name)
        elif best_habit_name:
            motivation = build_recovery_message(best_habit_name, 0)

    return RecommendationResponse(
        recommendations=all_recommendations,
        tips=tips,
        motivation_message=motivation,
    )

