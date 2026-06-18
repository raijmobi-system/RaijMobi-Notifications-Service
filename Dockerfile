FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . .

RUN mkdir -p /app/media

EXPOSE 8000

CMD ["sh", "-c", "python manage.py makemigrations --noinput && \
     python manage.py migrate --noinput && \
     python manage.py collectstatic --noinput && \
     python /app/notification_service/consumer.py --service ride & \
     python /app/notification_service/consumer.py --service user & \
     python /app/notification_service/consumer.py --service chat & \
     uvicorn core.asgi:application --host 0.0.0.0 --port 8000"]