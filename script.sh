#!/bin/bash
set -e

BASE_URL="http://localhost:8000"

echo "--- Registrando motorista ---"
DRIVER_RESP=$(curl -s -X POST "$BASE_URL/api/register/" \
  -F "email=motorista@teste.com" \
  -F "nome=Motorista Teste" \
  -F "password=Teste@123" \
  -F "cpf=123.456.789-09" \
  -F "telefone=11999999999" \
  -F "tipo_usuario=Motorista")
DRIVER_ID=$(echo $DRIVER_RESP | jq -r '.id')
if [ -z "$DRIVER_ID" ] || [ "$DRIVER_ID" = "null" ]; then
  echo "❌ Falha no registro do motorista. Resposta: $DRIVER_RESP"
  exit 1
fi
echo "✅ Motorista ID: $DRIVER_ID"

echo "--- Registrando passageiro ---"
PASSENGER_RESP=$(curl -s -X POST "$BASE_URL/api/register/" \
  -F "email=passageiro@teste.com" \
  -F "nome=Passageiro Teste" \
  -F "password=Teste@123" \
  -F "cpf=987.654.321-00" \
  -F "telefone=11988888888" \
  -F "tipo_usuario=Passageiro")
PASSENGER_ID=$(echo $PASSENGER_RESP | jq -r '.id')
if [ -z "$PASSENGER_ID" ] || [ "$PASSENGER_ID" = "null" ]; then
  echo "❌ Falha no registro do passageiro. Resposta: $PASSENGER_RESP"
  exit 1
fi
echo "✅ Passageiro ID: $PASSENGER_ID"

echo "--- Login motorista ---"
DRIVER_TOKEN=$(curl -s -X POST "$BASE_URL/api/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"motorista@teste.com","password":"Teste@123"}')
DRIVER_ACCESS=$(echo $DRIVER_TOKEN | jq -r '.access')
if [ -z "$DRIVER_ACCESS" ] || [ "$DRIVER_ACCESS" = "null" ]; then
  echo "❌ Falha no login do motorista. Resposta: $DRIVER_TOKEN"
  exit 1
fi
echo "✅ Motorista Access Token (primeiros 20): ${DRIVER_ACCESS:0:20}..."

echo "--- Login passageiro ---"
PASSENGER_TOKEN=$(curl -s -X POST "$BASE_URL/api/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"passageiro@teste.com","password":"Teste@123"}')
PASSENGER_ACCESS=$(echo $PASSENGER_TOKEN | jq -r '.access')
if [ -z "$PASSENGER_ACCESS" ] || [ "$PASSENGER_ACCESS" = "null" ]; then
  echo "❌ Falha no login do passageiro. Resposta: $PASSENGER_TOKEN"
  exit 1
fi
echo "✅ Passageiro Access Token (primeiros 20): ${PASSENGER_ACCESS:0:20}..."

echo "--- Criando veículo ---"
VEHICLE_RESP=$(curl -s -X POST "$BASE_URL/api/ride/vehicles/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"$DRIVER_ID\", \"model\":\"Fiat Uno\", \"color\":\"vermelho\", \"plate\":\"ABC1D23\", \"seats\":5, \"type_vehicle\":\"carro\"}")
VEHICLE_ID=$(echo $VEHICLE_RESP | jq -r '.id')
if [ -z "$VEHICLE_ID" ] || [ "$VEHICLE_ID" = "null" ]; then
  echo "❌ Falha ao criar veículo. Resposta: $VEHICLE_RESP"
  exit 1
fi
echo "✅ Veículo ID: $VEHICLE_ID"

echo "--- Criando carona ---"
START_TIME=$(date -u -d "+2 hours" +"%Y-%m-%dT%H:%M:%S.000Z")
EXPECTED_ARRIVAL=$(date -u -d "+3 hours" +"%Y-%m-%dT%H:%M:%S.000Z")
RIDE_RESP=$(curl -s -X POST "$BASE_URL/api/ride/rides/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"vehicle\":\"$VEHICLE_ID\", \"origin\":\"Terminal Central\", \"destination\":\"Aeroporto\", \"start_time\":\"$START_TIME\", \"expected_arrival\":\"$EXPECTED_ARRIVAL\", \"available_seats\":3, \"status\":\"pendente\", \"price\":45.00}")
RIDE_ID=$(echo $RIDE_RESP | jq -r '.id')
RIDE_UUID=$(echo $RIDE_RESP | jq -r '.uuid')
if [ -z "$RIDE_ID" ] || [ "$RIDE_ID" = "null" ]; then
  echo "❌ Falha ao criar carona. Resposta: $RIDE_RESP"
  exit 1
fi
echo "✅ Carona ID: $RIDE_ID, UUID: $RIDE_UUID"

echo "--- Criando reserva (passageiro) ---"
RESERVATION_RESP=$(curl -s -X POST "$BASE_URL/api/ride/reservations/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"ride\":\"$RIDE_ID\", \"passenger\":\"$PASSENGER_ID\", \"requested_seats\":2, \"status\":\"pendente\"}")
RESERVATION_ID=$(echo $RESERVATION_RESP | jq -r '.id')
if [ -z "$RESERVATION_ID" ] || [ "$RESERVATION_ID" = "null" ]; then
  echo "❌ Falha ao criar reserva. Resposta: $RESERVATION_RESP"
  exit 1
fi
echo "✅ Reserva ID: $RESERVATION_ID"

echo "--- Confirmando reserva (motorista) ---"
curl -s -X PATCH "$BASE_URL/api/ride/reservations/$RESERVATION_ID/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d '{"status":"confirmada"}' > /dev/null
echo "✅ Reserva confirmada"

echo "--- Aguardando processamento das notificações (5s) ---"
sleep 5

echo "--- Notificações do motorista (após reserva) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" | jq '.'

echo "--- Notificações do passageiro (após reserva) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" | jq '.'

# ============================================================
# NOVIDADE: TESTE DO CHAT E NOTIFICAÇÕES DE CHAT
# ============================================================

echo "--- Obtendo/criando sala de chat para a carona $RIDE_UUID ---"
# Tenta obter a sala primeiro (GET)
CHAT_ROOM_RESP=$(curl -s -X GET "$BASE_URL/api/chat/rooms/$RIDE_UUID/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS")
CHAT_ROOM_STATUS=$(echo $CHAT_ROOM_RESP | jq -r '.id // empty')

if [ -z "$CHAT_ROOM_STATUS" ]; then
  # Sala não existe, cria
  echo "Criando sala de chat..."
  CHAT_ROOM_RESP=$(curl -s -X POST "$BASE_URL/api/chat/rooms/" \
    -H "Authorization: Bearer $PASSENGER_ACCESS" \
    -H "Content-Type: application/json" \
    -d "{\"carona_id\":\"$RIDE_UUID\", \"driver_id\":\"$DRIVER_ID\", \"passenger_ids\":[\"$PASSENGER_ID\"]}")
  CHAT_ROOM_ID=$(echo $CHAT_ROOM_RESP | jq -r '.id')
  if [ -z "$CHAT_ROOM_ID" ] || [ "$CHAT_ROOM_ID" = "null" ]; then
    echo "❌ Falha ao criar sala de chat. Resposta: $CHAT_ROOM_RESP"
    exit 1
  fi
  echo "✅ Sala de chat criada: ID $CHAT_ROOM_ID"
else
  echo "✅ Sala de chat já existe: ID $CHAT_ROOM_STATUS"
fi

echo "--- Enviando mensagem do motorista no chat ---"
curl -s -X POST "$BASE_URL/api/chat/rooms/$RIDE_UUID/messages/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"usuario_id\":\"$DRIVER_ID\", \"conteudo\":\"Chego em 5 minutos.\"}" > /dev/null
echo "✅ Mensagem do motorista enviada"

echo "--- Enviando mensagem do passageiro no chat ---"
curl -s -X POST "$BASE_URL/api/chat/rooms/$RIDE_UUID/messages/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" \
  -H "Content-Type: application/json" \
  -d "{\"usuario_id\":\"$PASSENGER_ID\", \"conteudo\":\"Olá, estou no ponto!\"}" > /dev/null
echo "✅ Mensagem do passageiro enviada"

echo "--- Aguardando processamento das notificações do chat (5s) ---"
sleep 5

echo "--- Notificações do motorista (agora com chat) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $DRIVER_ACCESS" | jq '.'

echo "--- Notificações do passageiro (agora com chat) ---"
curl -s -X GET "$BASE_URL/api/notifications/" \
  -H "Authorization: Bearer $PASSENGER_ACCESS" | jq '.'

echo "--- Fim do teste ---"