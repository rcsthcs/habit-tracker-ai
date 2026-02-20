"""
LLM Provider — абстракция над LLM для лёгкой миграции.
Сейчас: Ollama (локально, бесплатно).
Потом: OpenAI API (подключить ключ — и всё работает).
"""
from abc import ABC, abstractmethod
from app.config import get_settings


class LLMProvider(ABC):
    """Abstract LLM interface."""

    @abstractmethod
    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        """Generate a response given system prompt, user message, and optional history."""
        ...


class OllamaProvider(LLMProvider):
    """Local Ollama LLM provider (free, runs on CPU)."""

    def __init__(self):
        settings = get_settings()
        self.model = settings.OLLAMA_MODEL
        self.base_url = settings.OLLAMA_BASE_URL

    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        try:
            import ollama
            messages = [{"role": "system", "content": system_prompt}]
            if history:
                messages.extend(history)
            messages.append({"role": "user", "content": user_message})

            client = ollama.AsyncClient(host=self.base_url)
            response = await client.chat(model=self.model, messages=messages)
            return response["message"]["content"]
        except Exception as e:
            return f"Извини, я сейчас не могу ответить (LLM недоступен: {type(e).__name__}). Попробуй позже!"


class FallbackProvider(LLMProvider):
    """
    Rule-based fallback when no LLM is available.
    Provides basic responses without AI.
    """

    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        msg_lower = user_message.lower()

        if any(w in msg_lower for w in ["привет", "здравствуй", "hello", "hi"]):
            return "Привет! 👋 Я твой помощник по привычкам. Спроси меня о статистике, попроси совет или просто поболтаем о твоих целях!"

        if any(w in msg_lower for w in ["статистик", "прогресс", "как дела"]):
            return "Чтобы посмотреть статистику, перейди на экран прогресса. Там ты увидишь серии, процент выполнения и графики! 📊"

        if any(w in msg_lower for w in ["совет", "рекомендац", "что делать", "помог"]):
            return ("Вот несколько советов:\n"
                    "1. 🎯 Начни с маленьких привычек — 2 минуты в день\n"
                    "2. 🔗 Привяжи новую привычку к существующей\n"
                    "3. 📅 Выполняй привычки в одно и то же время\n"
                    "4. 🏆 Отмечай свои успехи, даже маленькие!")

        if any(w in msg_lower for w in ["мотивац", "не хочу", "лень", "сложно", "трудно"]):
            return ("Я понимаю, бывает сложно. Помни:\n"
                    "💪 Даже 1% улучшения каждый день — это огромный результат за год\n"
                    "🌱 Не бойся начать заново — каждый день новый шанс\n"
                    "⭐ Ты уже молодец, что пользуешься приложением!")

        if any(w in msg_lower for w in ["добав", "новая привычка", "создать"]):
            return "Чтобы добавить привычку, нажми кнопку '+' на главном экране. Выбери категорию и время — я помогу подобрать оптимальное расписание! ➕"

        return ("Я твой помощник по привычкам! Вот что я умею:\n"
                "📊 Рассказать о прогрессе\n"
                "💡 Дать совет по привычкам\n"
                "💪 Помочь с мотивацией\n"
                "🆕 Подсказать новые привычки\n\n"
                "Просто спроси!")


class OpenAIProvider(LLMProvider):
    """
    OpenAI API provider — for future migration.
    Set OPENAI_API_KEY env variable and change config to use this.
    """

    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        # Placeholder for future migration
        # import openai
        # client = openai.AsyncOpenAI()
        # messages = [{"role": "system", "content": system_prompt}]
        # if history: messages.extend(history)
        # messages.append({"role": "user", "content": user_message})
        # response = await client.chat.completions.create(model="gpt-4", messages=messages)
        # return response.choices[0].message.content
        raise NotImplementedError("OpenAI provider not configured. Set OPENAI_API_KEY.")


def get_llm_provider() -> LLMProvider:
    """Factory: returns the appropriate LLM provider."""
    try:
        import ollama
        # Try to check if Ollama is running
        provider = OllamaProvider()
        return provider
    except ImportError:
        return FallbackProvider()

