FROM python:3.12-slim

WORKDIR /app

# Системные зависимости для scikit-learn, numpy, pandas
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ && \
    rm -rf /var/lib/apt/lists/*

# Сначала копируем requirements для кэширования слоёв
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем код приложения
COPY . .

# Создаём директории для данных и моделей
RUN mkdir -p /app/data/models

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

