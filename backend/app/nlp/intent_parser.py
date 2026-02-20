"""
Intent parser — быстрый разбор команд пользователя без LLM.
Для простых запросов (добавить привычку, статистика) — отвечаем мгновенно.
Для свободного диалога — передаём в LLM.
"""
import re
from dataclasses import dataclass
from enum import Enum


class Intent(str, Enum):
    ADD_HABIT = "add_habit"
    SHOW_STATS = "show_stats"
    SHOW_PROGRESS = "show_progress"
    GET_ADVICE = "get_advice"
    MOTIVATION = "motivation"
    GREETING = "greeting"
    HELP = "help"
    FREE_CHAT = "free_chat"  # Pass to LLM


@dataclass
class ParsedIntent:
    intent: Intent
    entities: dict  # Extracted entities (habit name, category, etc.)
    confidence: float


INTENT_PATTERNS = {
    Intent.GREETING: [
        r"(привет|здравствуй|добрый\s+(день|утро|вечер)|hello|\bhi\b|хай)",
    ],
    Intent.ADD_HABIT: [
        r"(добав|создай|новую?\s+привычк|хочу\s+начать|начать\s+привычк)",
    ],
    Intent.SHOW_STATS: [
        r"(статистик|аналитик|цифры|данные|сколько|процент)",
    ],
    Intent.SHOW_PROGRESS: [
        r"(прогресс|результат|достижени|серия|streak|как\s+дела)",
    ],
    Intent.GET_ADVICE: [
        r"(совет|рекомендац|подскаж|что\s+(делать|попробовать)|помог|tips)",
    ],
    Intent.MOTIVATION: [
        r"(мотивац|лень|не\s+хочу|сложно|трудно|устал|не\s+могу|сдаюсь)",
    ],
    Intent.HELP: [
        r"(помощь|help|что\s+ты\s+умеешь|команд|функци)",
    ],
}


def parse_intent(message: str) -> ParsedIntent:
    """Parse user message and extract intent."""
    msg_lower = message.lower().strip()
    entities = {}

    for intent, patterns in INTENT_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, msg_lower):
                # Try to extract habit name for ADD_HABIT
                if intent == Intent.ADD_HABIT:
                    # Try to find habit name after keywords
                    name_match = re.search(
                        r"(?:добав\w*|создай|начать)\s+(?:привычку?\s+)?[\"']?(.+)[\"']?\s*$",
                        msg_lower,
                        re.UNICODE,
                    )
                    if name_match:
                        entities["habit_name"] = name_match.group(1).strip()

                return ParsedIntent(intent=intent, entities=entities, confidence=0.8)

    # Default: free chat → send to LLM
    return ParsedIntent(intent=Intent.FREE_CHAT, entities={}, confidence=0.5)

