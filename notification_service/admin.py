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