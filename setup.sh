#!/bin/bash

echo "Инициализация n8n супер-агента..."

# Определение директории скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Проверка наличия Docker и Docker Compose
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и Docker Compose."
    exit 1
fi

if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose не установлен. Пожалуйста, установите Docker Compose."
    exit 1
fi

# Создание необходимых директорий
mkdir -p "$SCRIPT_DIR/logs/n8n" "$SCRIPT_DIR/logs/zep" "$SCRIPT_DIR/logs/postgres" "$SCRIPT_DIR/logs/postgres-zep" "$SCRIPT_DIR/logs/redis" "$SCRIPT_DIR/logs/nginx" "$SCRIPT_DIR/logs/weaviate"
mkdir -p "$SCRIPT_DIR/nginx/certs" "$SCRIPT_DIR/nginx/conf.d"
mkdir -p "$SCRIPT_DIR/workflows/prompts" "$SCRIPT_DIR/workflows/templates"

# Проверка .env файла
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Файл .env не найден. Создаем из шаблона..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo "Пожалуйста, отредактируйте файл .env и установите правильные значения API ключей."
fi

# Создание самоподписанных SSL-сертификатов, если их нет
if [ ! -f "$SCRIPT_DIR/nginx/certs/server.crt" ]; then
    echo "Создаем самоподписанные SSL сертификаты..."
    mkdir -p "$SCRIPT_DIR/nginx/certs"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/nginx/certs/server.key" -out "$SCRIPT_DIR/nginx/certs/server.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
fi

# Запуск Docker Compose
echo "Запуск контейнеров..."
cd "$SCRIPT_DIR" && docker-compose up -d

# Ожидание запуска сервисов
echo "Ожидание запуска сервисов..."
sleep 15

# Инициализация Weaviate
echo "Инициализация схемы Weaviate..."
docker exec -w /home/node/.n8n $(docker ps -qf "name=n8n-super-agent_n8n") node lib/init-weaviate.js

# Ожидаем завершения инициализации
sleep 5

# Получение токена API n8n
echo "Получение API токена n8n..."
N8N_API_KEY=$(docker exec $(docker ps -qf "name=n8n-super-agent_n8n") n8n user:api:create --first-user)
echo "API токен n8n: $N8N_API_KEY"

# Импорт шаблонов workflows
echo "Импорт шаблонов workflows..."
for template in "$SCRIPT_DIR/workflows/templates/"*.json; do
  if [ -f "$template" ]; then
    filename=$(basename -- "$template")
    echo "Импорт шаблона: $filename"
    curl -X POST "http://localhost:5678/rest/workflows" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d @"$template"
  fi
done

# Инициализация БД
echo "Инициализация базы данных..."
docker exec -i $(docker ps -qf "name=n8n-super-agent_postgres") psql -U n8n -d n8n < "$SCRIPT_DIR/init-db.sql"

echo "Установка завершена!"
echo "n8n доступен по адресу: https://localhost"
echo "Учетные данные по умолчанию: admin/admin (изменить в .env файле)"
echo ""
echo "Рекомендации:"
echo "1. Отредактируйте файл .env и установите безопасные пароли и API ключи"
echo "2. Создайте и импортируйте ваши собственные workflows"
echo "3. Для промышленного использования настройте правильные SSL-сертификаты"
