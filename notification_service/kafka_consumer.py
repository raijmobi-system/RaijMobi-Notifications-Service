import json
import os
import django
from confluent_kafka import Consumer, KafkaError, KafkaException

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from notification_service.models import Notification
from django.conf import settings

class NotificationConsumer:
    def __init__(self):
        conf = {
            'bootstrap.servers': settings.KAFKA_BOOTSTRAP_SERVERS,
            'group.id': settings.KAFKA_CONSUMER_GROUP,
            'auto.offset.reset': 'earliest',
        }
        self.consumer = Consumer(conf)
        self.topic = settings.KAFKA_NOTIFICATIONS_TOPIC
        self.running = True

    def start(self):
        self.consumer.subscribe([self.topic])
        try:
            while self.running:
                msg = self.consumer.poll(timeout=1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    else:
                        raise KafkaException(msg.error())
                self.process_message(msg.value())
        finally:
            self.consumer.close()

    def process_message(self, raw_value):
        try:
            data = json.loads(raw_value.decode('utf-8'))
            # Espera-se um JSON com: user_id, title, body, source, data (opcional)
            Notification.objects.create(
                user_id=data['user_id'],
                title=data['title'],
                body=data['body'],
                source=data.get('source', ''),
                data=data.get('data', {}),
            )
        except Exception as e:
            # Log do erro (substituir por logging adequado)
            print(f"Erro ao processar mensagem: {e}")

    def stop(self):
        self.running = False