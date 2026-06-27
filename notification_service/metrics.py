from prometheus_client import Counter

notifications_sent_total = Counter(
    "notifications_sent_total",
    "Total de notificacoes enviadas"
)

notifications_read_total = Counter(
    "notifications_read_total",
    "Total de notificacoes lidas"
)
notifications_from_ride_total  = Counter(
    "notifications_from_ride_total",
    "Total de notificacoes recebidas do Ride Service"
)

notifications_from_user_total = Counter(
    "notifications_from_user_total",
    "Total de notificacoes recebidas do User Service"
)

notifications_from_chat_total = Counter(
    "notifications_from_chat_total",
    "Total de notificacoes recebidas do Chat Service"
)