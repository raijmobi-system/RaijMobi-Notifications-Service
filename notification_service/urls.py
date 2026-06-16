from django.urls import path
from .views import UserNotificationsView

urlpatterns = [
    path('notifications/', UserNotificationsView.as_view(), name='user-notifications'),
]