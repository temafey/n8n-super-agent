#!/bin/bash

# Путь к проекту
PROJECT_DIR="/home/temafey/crypto-project/n8n-super-agent"
cd "$PROJECT_DIR"

# Получаем API ключ из файла
API_KEY=$(cat .n8n_api_key)

# Импорт шаблонов workflows через HTTPS
echo "Импорт шаблонов через HTTPS..."
for template in ./workflows/templates/*.json; do
  filename=$(basename -- "$template")
  echo "Импорт шаблона: $filename"
  
  # Отправляем запрос через curl с различными вариантами заголовка авторизации
  response=$(curl -k -X POST "https://localhost/rest/workflows" \
    -H "X-N8N-API-KEY: $API_KEY" \
    -H "Authorization: $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$template" -s)
  
  echo "Ответ: $response"
  
  # Если получена ошибка авторизации, попробуем через HTTP
  if [[ "$response" == *"Unauthorized"* ]]; then
    echo "Попытка импорта через HTTP..."
    response=$(curl -X POST "http://localhost:5678/rest/workflows" \
      -H "X-N8N-API-KEY: $API_KEY" \
      -H "Authorization: $API_KEY" \
      -H "Content-Type: application/json" \
      -d @"$template" -s)
    
    echo "Ответ HTTP: $response"
  fi
done

echo "Импорт завершен!"