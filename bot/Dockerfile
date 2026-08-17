FROM python:3.12-slim

WORKDIR /app

# Copiem lista de dependențe și le instalăm
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiem scriptul bot-ului
COPY bot.py .

# Păstrăm log-urile Python vizibile în consola Docker
ENV PYTHONUNBUFFERED=1 

CMD ["python", "bot.py"]
