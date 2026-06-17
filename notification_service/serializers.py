# notifications/serializers.py
from rest_framework import serializers
from .models import Notification

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user_id', 'message', 'service_origin', 'read', 'created_at']
        read_only_fields = ['id', 'user_id', 'message', 'service_origin', 'created_at']