"""
Habit Difficulty Classifier — определяет, какие привычки даются легко, а какие сложно.
Использует RandomForest при достаточном количестве данных, иначе — rule-based fallback.
"""
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
import joblib
import os
from pathlib import Path
from app.config import get_settings


class HabitDifficultyClassifier:
    LABELS = ["easy", "medium", "hard"]

    def __init__(self):
        self.model: RandomForestClassifier | None = None
        self.category_encoder = LabelEncoder()
        self.is_trained = False
        settings = get_settings()
        self.model_dir = Path(settings.MODEL_STORE_PATH)
        self.model_dir.mkdir(parents=True, exist_ok=True)

    def _extract_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Extract features per habit from log data."""
        features = df.groupby(["habit_id", "habit_name", "category"]).agg(
            completion_rate=("completed", "mean"),
            total_logs=("completed", "count"),
            avg_day_of_week=("day_of_week", "mean"),
            std_day_of_week=("day_of_week", "std"),
            avg_hour=("hour", lambda x: x.dropna().mean() if x.dropna().any() else 12),
        ).reset_index()

        features["std_day_of_week"] = features["std_day_of_week"].fillna(0)
        return features

    def _label_difficulty(self, completion_rate: float) -> str:
        """Rule-based difficulty labeling."""
        if completion_rate >= 0.75:
            return "easy"
        elif completion_rate >= 0.45:
            return "medium"
        else:
            return "hard"

    def train(self, df: pd.DataFrame) -> bool:
        """Train classifier on user's habit log data. Returns True if ML model trained."""
        if df.empty:
            return False

        features = self._extract_features(df)
        if len(features) < 3:
            return False

        # Create labels from completion rates
        features["difficulty"] = features["completion_rate"].apply(self._label_difficulty)

        # Encode category
        features["category_encoded"] = self.category_encoder.fit_transform(
            features["category"].astype(str)
        )

        X = features[["completion_rate", "total_logs", "avg_day_of_week",
                       "std_day_of_week", "avg_hour", "category_encoded"]].values
        y = features["difficulty"].values

        settings = get_settings()
        if len(features) >= settings.MIN_LOGS_FOR_ML:
            self.model = RandomForestClassifier(n_estimators=50, random_state=42, max_depth=5)
            self.model.fit(X, y)
            self.is_trained = True

            # Save model
            joblib.dump(self.model, self.model_dir / "difficulty_classifier.pkl")
            joblib.dump(self.category_encoder, self.model_dir / "category_encoder.pkl")
            return True

        return False

    def predict(self, df: pd.DataFrame) -> list[dict]:
        """Predict difficulty for each habit. Falls back to rule-based if no ML model."""
        if df.empty:
            return []

        features = self._extract_features(df)
        results = []

        for _, row in features.iterrows():
            if self.is_trained and self.model:
                try:
                    cat_encoded = self.category_encoder.transform([str(row["category"])])[0]
                    X = np.array([[row["completion_rate"], row["total_logs"],
                                   row["avg_day_of_week"], row["std_day_of_week"],
                                   row["avg_hour"], cat_encoded]])
                    difficulty = self.model.predict(X)[0]
                except (ValueError, KeyError):
                    difficulty = self._label_difficulty(row["completion_rate"])
            else:
                difficulty = self._label_difficulty(row["completion_rate"])

            results.append({
                "habit_id": int(row["habit_id"]),
                "habit_name": row["habit_name"],
                "difficulty": difficulty,
                "completion_rate": round(row["completion_rate"] * 100, 1),
            })

        return results

    def load_model(self) -> bool:
        """Try to load a previously trained model."""
        model_path = self.model_dir / "difficulty_classifier.pkl"
        encoder_path = self.model_dir / "category_encoder.pkl"
        if model_path.exists() and encoder_path.exists():
            self.model = joblib.load(model_path)
            self.category_encoder = joblib.load(encoder_path)
            self.is_trained = True
            return True
        return False

