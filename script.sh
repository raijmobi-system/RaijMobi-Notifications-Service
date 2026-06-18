#!/bin/bash
set -e

BASE_URL="http://localhost:8000"

echo "--- Registrando motorista ---"
DRIVER_RESP=$(curl -s -X POST "$BASE_URL/api/register/" \
  -F "email=motorista@teste.com" \
  -F "nome=Motorista Teste" \
  -F "password=Teste@123" \
  -F "cpf=123.456.789-09" \
  -F "telefone=11999999999" \
  -F "tipo_usuario=Motorista")
DRIVER_ID=$(echo $DRIVER_RESP | jq -r '.id')
if [ -z "$DRIVER_ID" ] || [ "$DRIVER_ID" = "null" ]; then
  echo "❌ Falha no registro do motorista. Resposta: $DRIVER_RESP"
  exit 1
fi
echo "✅ Motorista ID: $DRIVER_ID"

echo "--- Registrando passageiro ---"
PASSENGER_RESP=$(curl -s -X POST "$BASE_URL/api/register/" \
  -F "email=passageiro@teste.com" \
  -F "nome=Passageiro Teste" \
  -F "password=Teste@123" \
  -F "cpf=987.654.321-00" \
  -F "telefone=11988888888" \
  -F "tipo_usuario=Passageiro")
PASSENGER_ID=$(echo $PASSENGER_RESP | jq -r '.id')
if [ -z "$PASSENGER_ID" ] || [ "$PASSENGER_ID" = "null" ]; then
  echo "❌ Falha no registro do passageiro. Resposta: $PASSENGER_RESP"
  exit 1
fi
echo "✅ Passageiro ID: $PASSENGER_ID"

echo "--- Login motorista ---"
DRIVER_TOKEN=$(curl -s -X POST "$BASE_URL/api/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"motorista@teste.com","password":"Teste@123"}')
DRIVER_ACCESS=$(echo $DRIVER_TOKEN | jq -r '.access')
if [ -z "$DRIVER_ACCESS" ] || [ "$DRIVER_ACCESS" = "null" ]; then
  echo "❌ Falha no login do motorista. Resposta: $DRIVER_TOKEN"
  exit 1
fi
echo "✅ Motorista Access Token (primeiros 20): ${DRIVER_ACCESS:0:20}..."

echo "--- Login passageiro ---"
PASSENGER_TOKEN=$(curl -s -X POST "$BASE_URL/api/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"passageiro@teste.com","password":"Teste@123"}')
PASSENGER_ACCESS=$(echo $PASSENGER_TOKEN | jq -r '.access')
if [ -z "$PASSENGER_ACCESS" ] || [ "$PASSENGER_ACCESS" = "null" ]; then
  echo "❌ Falha no login do passageiro. Resposta: $PASSENGER_TOKEN"
  exit 1
fi
echo "✅ Passageiro Access Token (primeiros 20): ${PASSENGER_ACCESS:0:20}..."

echo "--- Criando veículo ---"
VEHICLE_RESP=$(curl -s -X POST "$BASE_URL/api/ride/vehicles/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"$DRIVER_ID\", \"model\":\"Fiat Uno\", \"color\":\"vermelho\", \"plate\":\"ABC1D23\", \"seats\":5, \"type_vehicle\":\"carro\"}")
VEHICLE_ID=$(echo $VEHICLE_RESP | jq -r '.id')
if [ -z "$VEHICLE_ID" ] || [ "$VEHICLE_ID" = "null" ]; then
  echo "❌ Falha ao criar veículo. Resposta: $VEHICLE_RESP"
  exit 1
fi
echo "✅ Veículo ID: $VEHICLE_ID"

echo "--- Criando carona ---"
START_TIME=$(date -u -d "+2 hours" +"%Y-%m-%dT%H:%M:%S.000Z")
EXPECTED_ARRIVAL=$(date -u -d "+3 hours" +"%Y-%m-%dT%H:%M:%S.000Z")
RIDE_RESP=$(curl -s -X POST "$BASE_URL/api/ride/rides/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"vehicle\":\"$VEHICLE_ID\", \"origin\":\"Terminal Central\", \"destination\":\"Aeroporto\", \"start_time\":\"$START_TIME\", \"expected_arrival\":\"$EXPECTED_ARRIVAL\", \"available_seats\":3, \"status\":\"pendente\", \"price\":45.00}")
RIDE_ID=$(echo $RIDE_RESP | jq -r '.id')
RIDE_UUID=$(echo $RIDE_RESP | jq -r '.uuid')
if [ -z "$RIDE_ID" ] || [ "$RIDE_ID" = "null" ]; then
  echo "❌ Falha ao criar carona. Resposta: $RIDE_RESP"
  exit 1
fi
echo "✅ Carona ID: $RIDE_ID, UUID: $RIDE_UUID"

echo "--- Criando reserva (passageiro) ---"
RESERVATION_RESP=$(curl -s -X POST "$BASE_URL/api/ride/reservations/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"ride\":\"$RIDE_ID\", \"passenger\":\"$PASSENGER_ID\", \"requested_seats\":2, \"status\":\"pendente\"}")
RESERVATION_ID=$(echo $RESERVATION_RESP | jq -r '.id')
if [ -z "$RESERVATION_ID" ] || [ "$RESERVATION_ID" = "null" ]; then
  echo "❌ Falha ao criar reserva. Resposta: $RESERVATION_RESP"
  exit 1
fi
echo "✅ Reserva ID: $RESERVATION_ID"

echo "--- Confirmando reserva (motorista) ---"
curl -s -X PATCH "$BASE_URL/api/ride/reservations/$RESERVATION_ID/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d '{"status":"confirmada"}' > /dev/null
echo "✅ Reserva confirmada"

echo "--- Aguardando processamento das notificações (5s) ---"
sleep 5

echo "--- Notificações do motorista (após reserva) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" | jq '.'

echo "--- Notificações do passageiro (após reserva) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" | jq '.'

# ============================================================
# NOVIDADE: TESTE DO CHAT E NOTIFICAÇÕES DE CHAT
# ============================================================

echo "--- Obtendo/criando sala de chat para a carona $RIDE_UUID ---"
# Tenta obter a sala primeiro (GET)
CHAT_ROOM_RESP=$(curl -s -X GET "$BASE_URL/api/chat/rooms/$RIDE_UUID/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS")
CHAT_ROOM_STATUS=$(echo $CHAT_ROOM_RESP | jq -r '.id // empty')

if [ -z "$CHAT_ROOM_STATUS" ]; then
  # Sala não existe, cria
  echo "Criando sala de chat..."
  CHAT_ROOM_RESP=$(curl -s -X POST "$BASE_URL/api/chat/rooms/" \
    -H "Authorization: Bearer $PASSENGER_ACCESS" \
    -H "Content-Type: application/json" \
    -d "{\"carona_id\":\"$RIDE_UUID\", \"driver_id\":\"$DRIVER_ID\", \"passenger_ids\":[\"$PASSENGER_ID\"]}")
  CHAT_ROOM_ID=$(echo $CHAT_ROOM_RESP | jq -r '.id')
  if [ -z "$CHAT_ROOM_ID" ] || [ "$CHAT_ROOM_ID" = "null" ]; then
    echo "❌ Falha ao criar sala de chat. Resposta: $CHAT_ROOM_RESP"
    exit 1
  fi
  echo "✅ Sala de chat criada: ID $CHAT_ROOM_ID"
else
  echo "✅ Sala de chat já existe: ID $CHAT_ROOM_STATUS"
fi

echo "--- Enviando mensagem do motorista no chat ---"
curl -s -X POST "$BASE_URL/api/chat/rooms/$RIDE_UUID/messages/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"usuario_id\":\"$DRIVER_ID\", \"conteudo\":\"Chego em 5 minutos.\"}" > /dev/null
echo "✅ Mensagem do motorista enviada"

echo "--- Enviando mensagem do passageiro no chat ---"
curl -s -X POST "$BASE_URL/api/chat/rooms/$RIDE_UUID/messages/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"usuario_id\":\"$PASSENGER_ID\", \"conteudo\":\"Olá, estou no ponto!\"}" > /dev/null
echo "✅ Mensagem do passageiro enviada"

echo "--- Aguardando processamento das notificações do chat (5s) ---"
sleep 5

echo "--- Notificações do motorista (agora com chat) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" | jq '.'

echo "--- Notificações do passageiro (agora com chat) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" | jq '.'

echo "--- Fim do teste ---"
===== RaijMobi-Notifications-Service/notification_service/urls.py =====
# notifications/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('notifications/', views.NotificationListView.as_view(), name='notification-list'),
    path('notifications/<int:pk>/read/', views.mark_as_read, name='notification-read'),
]
===== RaijMobi-Notifications-Service/notification_service/models.py =====
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager

class UserManager(BaseUserManager):
    def create_user(self, id, username=''):
        if not id:
            raise ValueError('O campo id é obrigatório')
        user = self.model(id=id, username=username)
        user.save(using=self._db)
        return user

    def create_superuser(self, id, username=''):
        return self.create_user(id, username)  # não necessário

class User(AbstractBaseUser):
    id = models.CharField(max_length=255, primary_key=True)  # mesmo id dos outros serviços
    username = models.CharField(max_length=150, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = 'id'
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.id

class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    message = models.TextField()
    service_origin = models.CharField(max_length=50)  # 'ride' ou 'user'
    read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
===== RaijMobi-Notifications-Service/notification_service/tests.py =====
from django.test import TestCase

# Create your tests here.

===== RaijMobi-Notifications-Service/notification_service/serializers.py =====
# notifications/serializers.py
from rest_framework import serializers
from .models import Notification

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user_id', 'message', 'service_origin', 'read', 'created_at']
        read_only_fields = ['id', 'user_id', 'message', 'service_origin', 'created_at']
===== RaijMobi-Notifications-Service/notification_service/__init__.py =====

===== RaijMobi-Notifications-Service/notification_service/authentication.py =====
from rest_framework_simplejwt.authentication import JWTAuthentication
from notification_service.models import User

class CustomJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user_id = validated_token.get('user_id')
        if not user_id:
            return None
        # Cria o usuário se ainda não existir (ex: primeiro acesso)
        user, _ = User.objects.get_or_create(id=user_id)
        return user
===== RaijMobi-Notifications-Service/notification_service/consumer.py =====
import os
import sys
import json
import argparse
import signal

# Garante que a raiz do projeto está no PYTHONPATH
sys.path.append('/app')

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
import django
django.setup()

from confluent_kafka import Consumer, KafkaError
from notification_service.models import User, Notification

def create_consumer(bootstrap_servers, group_id, topics):
    conf = {
        'bootstrap.servers': bootstrap_servers,
        'group.id': group_id,
        'auto.offset.reset': 'earliest',
    }
    consumer = Consumer(conf)
    consumer.subscribe(topics)
    return consumer

def process_message(msg,service):
    try:
        data = json.loads(msg.value().decode('utf-8'))
        user_id = data.get('user_id')
        message_text = data.get('message', '')
        if not user_id:
            print("Mensagem sem user_id, ignorando")
            return
        user, _ = User.objects.get_or_create(
            id=user_id,
            defaults={'username': data.get('username', '')}
        )
        Notification.objects.create(
            user=user,
            message=message_text,
            service_origin=service,   
        )
        print(f"Notificação criada para user {user_id}")
    except Exception as e:
        print(f"Erro ao processar mensagem: {e}")

def run_consumer(service):
    if service == 'ride':
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_RIDE']
        topics = os.environ.get('KAFKA_TOPICS_RIDE', 'ride_notifications').split(',')
        group_id = 'notification-service-ride'
    elif service == 'user':
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_USER']
        topics = os.environ.get('KAFKA_TOPICS_USER', 'user_notifications').split(',')
        group_id = 'notification-service-user'
    elif service == 'chat':   # ← NOVO BLOCO
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_USER']   # mesmo broker do user
        topics = os.environ.get('KAFKA_TOPICS_CHAT', 'chat_notifications').split(',')
        group_id = 'notification-service-chat'
    else:
        print("Serviço desconhecido. Use --service ride|user|chat")
        sys.exit(1)

    consumer = create_consumer(bootstrap, group_id, topics)

    def shutdown(sig, frame):
        print("Desligando consumer...")
        consumer.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    print(f"Consumer do {service} iniciado. Tópicos: {topics}")
    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                print(f"Erro Kafka: {msg.error()}")
                continue
            process_message(msg, service)
    finally:
        consumer.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--service', required=True, choices=['ride', 'user'])
    args = parser.parse_args()
    run_consumer(args.service)
===== RaijMobi-Notifications-Service/notification_service/views.py =====
# notifications/views.py
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from .models import Notification
from .serializers import NotificationSerializer

class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def mark_as_read(request, pk):
    try:
        notification = Notification.objects.get(pk=pk, user=request.user)
        notification.read = True
        notification.save()
        return Response(NotificationSerializer(notification).data)
    except Notification.DoesNotExist:
        return Response({'error': 'Notificação não encontrada'}, status=404)
===== RaijMobi-Notifications-Service/notification_service/apps.py =====
from django.apps import AppConfig


class NotificationServiceConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notification_service'

===== RaijMobi-Notifications-Service/notification_service/admin.py =====
from django.contrib import admin
from .models import User, Notification

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['id', 'username', 'created_at']
    search_fields = ['id', 'username']

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'message', 'service_origin', 'read', 'created_at']
    list_filter = ['service_origin', 'read']
    search_fields = ['message', 'user__id']
===== RaijMobi-Ride-Service/pyproject.toml =====
[project]
name = "raijmobi-ride-service"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.14"
dependencies = [
    "django-filter>=25.2",
    "djangorestframework>=3.17.1",
]

[dependency-groups]
dev = [
    "faker>=40.15.0",
]

===== RaijMobi-Ride-Service/ride_service/urls.py =====
from django.contrib import admin
from django.urls import path,include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/ride/', include('core.urls')),
]