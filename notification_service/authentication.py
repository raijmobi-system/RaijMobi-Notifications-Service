from rest_framework_simplejwt.authentication import JWTAuthentication
from notification_service.models import User

class CustomJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user_id = validated_token.get('user_id')
        if not user_id:
            return None
        # Cria o usuário se ainda não existir (ex: primeiro acesso)
        user, _ = User.objects.get_or_create(id=user_id)
        return user