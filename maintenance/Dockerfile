FROM postgres:15

# Copia os scripts para o container
COPY maintenance.sh /usr/local/bin/maintenance.sh
COPY start.sh /usr/local/bin/start.sh

# Dá permissão de execução
RUN chmod +x /usr/local/bin/maintenance.sh /usr/local/bin/start.sh

# Comando padrão que roda ao iniciar o container
CMD ["/usr/local/bin/start.sh"]