# Imagem base
FROM python:3.11-slim

# Variáveis de ambiente
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Diretório de trabalho
WORKDIR /app

# Copia requirements primeiro (melhor cache)
COPY requirements.txt .

# Instala dependências
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copia o restante do projeto
COPY . .
RUN mkdir -p /app/media

# Porta do Django
EXPOSE 8000

# Comando para rodar (será sobrescrito no docker-compose)
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]