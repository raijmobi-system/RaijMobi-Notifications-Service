from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('notification_service.urls')),
    path("",include("django_prometheus.urls")),
]