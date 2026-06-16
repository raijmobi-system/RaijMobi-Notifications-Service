from django.db import models

# Create your models here.
from django.db import models
import uuid

class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user_id = models.UUIDField(db_index=True)        # ID do usuário destinatário
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField(default=dict, blank=True) # payload extra (opcional)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # Opcional: de qual serviço veio (serviço A, serviço B)
    source = models.CharField(max_length=50, blank=True)

    class Meta:
        ordering = ['-created_at']