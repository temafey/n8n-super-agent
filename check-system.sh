#!/bin/bash

echo "Проверка системы n8n супер-агента..."

# Проверка запущенных контейнеров
echo -e "\n=== Проверка запущенных контейнеров ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Проверка логов n8n
echo -e "\n=== Последние логи n8n ==="
docker logs --tail 20 $(docker ps -qf "name=n8n-super-agent_n8n")

# Проверка доступности Weaviate
echo -e "\n=== Проверка доступности Weaviate ==="
curl -s http://localhost:8087/v1/.well-known/ready || echo "Weaviate недоступен!"

# Проверка доступности Redis
echo -e "\n=== Проверка доступности Redis ==="
docker exec $(docker ps -qf "name=n8n-super-agent_redis") redis-cli ping || echo "Redis недоступен!"

# Проверка доступности сервиса эмбеддингов
echo -e "\n=== Проверка доступности сервиса эмбеддингов ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/info || echo "Сервис эмбеддингов недоступен!"

# Проверка доступности n8n API
echo -e "\n=== Проверка доступности n8n API ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/rest/health || echo "n8n API недоступен!"

# Проверка импортированных workflows
echo -e "\n=== Проверка импортированных workflows ==="
N8N_API_KEY=$(docker exec $(docker ps -qf "name=n8n-super-agent_n8n") n8n user:list | grep -o "API key: [a-zA-Z0-9]*" | cut -d " " -f 3)
if [ -n "$N8N_API_KEY" ]; then
  curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" http://localhost:5678/rest/workflows | jq -r '.[].name'
else
  echo "Не удалось получить API ключ n8n"
fi

echo -e "\n=== Проверка завершена ==="
echo "Если все сервисы запущены, система готова к использованию."
echo "Откройте https://localhost в браузере для доступа к интерфейсу n8n."
