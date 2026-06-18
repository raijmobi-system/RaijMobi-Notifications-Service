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
    parser.add_argument('--service', required=True, choices=['ride', 'user', 'chat'])
    args = parser.parse_args()
    run_consumer(args.service)