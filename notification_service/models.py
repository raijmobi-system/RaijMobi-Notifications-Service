from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager

class UserManager(BaseUserManager):
    def create_user(self, id, username=''):
        if not id:
            raise ValueError('O campo id é obrigatório')
        user = self.model(id=id, username=username)
        user.save(using=self._db)
        return user

    def create_superuser(self, id, username=''):
        return self.create_user(id, username)  # não necessário

class User(AbstractBaseUser):
    id = models.CharField(max_length=255, primary_key=True)  # mesmo id dos outros serviços
    username = models.CharField(max_length=150, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = 'id'
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.id

class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    message = models.TextField()
    service_origin = models.CharField(max_length=50)  # 'ride' ou 'user'
    read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']