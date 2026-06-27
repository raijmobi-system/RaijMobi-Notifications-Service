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
from .metrics import notifications_read_total,notifications_from_chat_total,notifications_from_ride_total,notifications_from_user_total,notifications_sent_total

def create_consumer(bootstrap_servers, group_id, topics):
    conf = {
        'bootstrap.servers': bootstrap_servers,
        'group.id': group_id,
        'auto.offset.reset': 'earliest',
    }
    consumer = Consumer(conf)
    consumer.subscribe(topics)
    return consumer

def process_message(msg, service):
    try:
        data = json.loads(msg.value().decode('utf-8'))

        # Trata eventos de criação/atualização de usuário
        if service == 'user-events':
            user_id = data.get('id')
            name = data.get('name', '')
            if user_id:
                User.objects.update_or_create(
                    id=user_id,
                    defaults={
                        'username': name,
                        'email': data.get('email', ''),
                        'is_driver': data.get('is_driver', False),
                    }
                )
                print(f"Usuário {user_id} sincronizado (nome: {name})")
            return

        # Para os demais serviços (ride, user, chat) – notificações
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

        notifications_sent_total.inc()

        if service == "ride":
            notifications_from_ride_total.inc()

        elif service == "user":
            notifications_from_user_total.inc()

        elif service == "chat":
            notifications_from_chat_total.inc()

        print(f"Notificação criada para user {user_id}")

    except Exception as e:
        print(f"Erro ao processar mensagem: {e}")

def run_consumer(service):
    # Configuração do consumidor conforme o serviço
    if service == 'ride':
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_RIDE']
        topics = os.environ.get('KAFKA_TOPICS_RIDE', 'ride_notifications').split(',')
        group_id = 'notification-service-ride'
    elif service == 'user':
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_USER']
        topics = os.environ.get('KAFKA_TOPICS_USER', 'user_notifications').split(',')
        group_id = 'notification-service-user'
    elif service == 'chat':
        bootstrap = os.environ['KAFKA_BOOTSTRAP_SERVERS_USER']
        topics = os.environ.get('KAFKA_TOPICS_CHAT', 'chat_notifications').split(',')
        group_id = 'notification-service-chat'
    elif service == 'user-events':
        bootstrap = os.environ.get('KAFKA_BOOTSTRAP_SERVERS_USER', 'kafka-user:9092')
        topics = ['user-events']
        group_id = 'notification-service-user-events'
    else:
        print("Serviço desconhecido. Use --service ride|user|chat|user-events")
        sys.exit(1)

    # Cria o consumidor
    consumer = create_consumer(bootstrap, group_id, topics)

    # Define a função shutdown (deve ser definida ANTES de ser usada)
    def shutdown(sig, frame):
        print("Desligando consumer...")
        consumer.close()
        sys.exit(0)

    # Registra os manipuladores de sinal
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
    parser.add_argument('--service', required=True, choices=['ride', 'user', 'chat', 'user-events'])
    args = parser.parse_args()
    run_consumer(args.service)