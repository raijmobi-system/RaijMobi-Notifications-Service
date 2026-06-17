# notifications/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('api/notifications/', views.NotificationListView.as_view(), name='notification-list'),
    path('api/notifications/<int:pk>/read/', views.mark_as_read, name='notification-read'),
]