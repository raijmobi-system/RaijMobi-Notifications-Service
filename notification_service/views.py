# notifications/views.py
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from .models import Notification
from .serializers import NotificationSerializer
from .metrics import (notifications_read_total,notifications_sent_total,notifications_from_ride_total,notifications_from_user_total,notifications_from_chat_total,)

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

        if not notification.read:
            notification.read = True
            notification.save()
            notifications_read_total.inc()

        return Response(NotificationSerializer(notification).data)
    except Notification.DoesNotExist:
        return Response({'error': 'Notificação não encontrada'}, status=404)