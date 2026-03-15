"""
LLM Provider — абстракция над LLM для лёгкой миграции.
Сейчас: Ollama (локально, бесплатно).
Потом: OpenAI API (подключить ключ — и всё работает).
"""
from abc import ABC, abstractmethod
import asyncio
import requests
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


class GeminiProvider(LLMProvider):
    """Google AI Studio (Gemini) provider via REST API."""

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.GEMINI_API_KEY
        self.model = settings.GEMINI_MODEL

    @staticmethod
    def _map_role(role: str) -> str:
        if role in ("assistant", "model"):
            return "model"
        return "user"

    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        if not self.api_key:
            return "Gemini API ключ не настроен на сервере."

        contents = []
        for msg in history or []:
            text = (msg.get("content") or "").strip()
            if not text:
                continue
            contents.append(
                {
                    "role": self._map_role(msg.get("role", "user")),
                    "parts": [{"text": text}],
                }
            )

        contents.append({"role": "user", "parts": [{"text": user_message}]})

        payload = {
            "system_instruction": {"parts": [{"text": system_prompt}]},
            "contents": contents,
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 800,
            },
        }

        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self.model}:generateContent?key={self.api_key}"
        )

        def _request() -> str:
            response = requests.post(url, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            candidates = data.get("candidates") or []
            if not candidates:
                raise ValueError("No candidates in Gemini response")

            parts = ((candidates[0].get("content") or {}).get("parts") or [])
            texts = [p.get("text", "") for p in parts if p.get("text")]
            if not texts:
                raise ValueError("Empty Gemini response text")
            return "\n".join(texts).strip()

        try:
            return await asyncio.to_thread(_request)
        except Exception as e:
            return f"Извини, я сейчас не могу ответить (Gemini недоступен: {type(e).__name__}). Попробуй позже!"


class OpenRouterProvider(LLMProvider):
    """OpenRouter API provider."""

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.OPENROUTER_API_KEY
        self.model = settings.OPENROUTER_MODEL

    async def generate(self, system_prompt: str, user_message: str, history: list[dict] = None) -> str:
        if not self.api_key:
            return "OpenRouter API ключ не настроен."

        messages = [{"role": "system", "content": system_prompt}]
        if history:
            messages.extend(history)
        messages.append({"role": "user", "content": user_message})

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.7,
        }

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": "http://localhost:8000",
            "X-Title": "HabitTrackerAI",
            "Content-Type": "application/json"
        }

        url = "https://openrouter.ai/api/v1/chat/completions"

        def _request() -> str:
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"].strip()

        try:
            return await asyncio.to_thread(_request)
        except Exception as e:
            return f"Извини, я сейчас не могу ответить (OpenRouter недоступен: {type(e).__name__}). Попробуй позже!"


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
    import os
    settings = get_settings()
    provider_name = (settings.LLM_PROVIDER or "auto").lower()

    # Highest priority legacy flag
    if os.getenv("DISABLE_OLLAMA", "").lower() in ("1", "true", "yes"):
        return FallbackProvider()

    if provider_name == "fallback":
        return FallbackProvider()

    if provider_name == "gemini":
        return GeminiProvider() if settings.GEMINI_API_KEY else FallbackProvider()

    if provider_name == "openrouter":
        return OpenRouterProvider() if settings.OPENROUTER_API_KEY else FallbackProvider()

    if provider_name == "ollama":
        import requests
        try:
            # Check if ollama is actually running
            requests.get(settings.OLLAMA_BASE_URL, timeout=1)
            import ollama
            return OllamaProvider()
        except (requests.exceptions.RequestException, ImportError):
            if settings.OPENROUTER_API_KEY:
                return OpenRouterProvider()
            return FallbackProvider()

    # auto mode: prefer Gemini key, otherwise Ollama, otherwise OpenRouter, otherwise fallback
    if settings.GEMINI_API_KEY:
        return GeminiProvider()

    if settings.OPENROUTER_API_KEY:
        # Check if ollama is actually running first in auto mode
        try:
            import requests
            requests.get(settings.OLLAMA_BASE_URL, timeout=1)
            import ollama
            return OllamaProvider()
        except (requests.exceptions.RequestException, ImportError):
            return OpenRouterProvider()

    try:
        import requests
        requests.get(settings.OLLAMA_BASE_URL, timeout=1)
        import ollama
        return OllamaProvider()
    except (requests.exceptions.RequestException, ImportError):
        return FallbackProvider()

