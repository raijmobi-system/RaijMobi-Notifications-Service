from django.shortcuts import render

# Create your views here.
from rest_framework import generics, permissions
from .models import Notification
from .serializers import NotificationSerializer

class UserNotificationsView(generics.ListAPIView):
    """
    GET /api/notifications/?user_id=<uuid>
    Retorna todas as notificações do usuário, ordenadas por data decrescente.
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]  # se usar JWT

    def get_queryset(self):
        user_id = self.request.query_params.get('user_id')
        if not user_id:
            return Notification.objects.none()
        return Notification.objects.filter(user_id=user_id)