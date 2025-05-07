#!/bin/bash

# Определяем путь к текущему скрипту и каталогу проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Функция вывода справки
show_help() {
  echo "Использование: $0 [опции] [имя_файла]"
  echo ""
  echo "Опции:"
  echo "  -h, --help       Показать эту справку"
  echo ""
  echo "Аргументы:"
  echo "  [имя_файла]      Имя конкретного файла workflow для импорта"
  echo "                   (без указания файла будут импортированы все workflows)"
  echo ""
  echo "Примеры:"
  echo "  $0               # Импортировать все файлы workflow"
  echo "  $0 tiktok.json   # Импортировать только tiktok.json"
  echo ""
}

# Обработка аргументов командной строки
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  show_help
  exit 0
fi

# Получаем API ключ из файла
if [ ! -f ".n8n_api_key" ]; then
  echo "ОШИБКА: Файл .n8n_api_key не найден."
  exit 1
fi

API_KEY=$(cat .n8n_api_key)

if [ -z "$API_KEY" ]; then
  echo "ОШИБКА: API ключ пустой или не удалось его прочитать."
  exit 1
fi

# Определяем хосты и порты
N8N_HOST=${N8N_HOST:-"localhost"}
N8N_PORT=${N8N_PORT:-"5678"}
N8N_HTTPS_PORT=${N8N_HTTPS_PORT:-"443"}
USE_HTTPS=${USE_HTTPS:-true}

# Определяем API URL в зависимости от настроек
if [ "$USE_HTTPS" = true ]; then
  API_URL="https://$N8N_HOST/api/v1/workflows"
  CURL_OPTS="-k"  # Пропускать проверку SSL
else
  API_URL="http://$N8N_HOST:$N8N_PORT/api/v1/workflows"
  CURL_OPTS=""
fi

echo "Используем API URL: $API_URL"

# Функция для импорта одного шаблона
import_template() {
  local template="$1"
  local filename=$(basename -- "$template")

  echo "Импорт шаблона: $filename"

  # Отправляем запрос через curl
  response=$(curl $CURL_OPTS -X POST "$API_URL" \
    -H "X-N8N-API-KEY: $API_KEY" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d @"$template" -s)

  # Всегда выводим полный ответ для анализа
  echo "Полный ответ API для $filename:"
  echo "$response"

  # Проверяем наличие ID в ответе
  if echo "$response" | grep -q "\"id\":"; then
    echo "✅ Workflow ID обнаружен для: $filename"

    # Дополнительные проверки
    if echo "$response" | grep -q "\"error\":"; then
      echo "⚠️ Обнаружены ошибки при импорте!"
    fi

    if echo "$response" | grep -q "\"warnings\":"; then
      echo "⚠️ Обнаружены предупреждения при импорте!"
    fi

    # Проверка на пустые узлы
    nodes_count=$(echo "$response" | grep -o "\"nodes\":" | wc -l)
    if [ "$nodes_count" -eq 0 ]; then
      echo "⚠️ Workflow импортирован без узлов (пустой)!"
    fi
  else
    echo "❌ Не удалось импортировать шаблон: $filename"
  fi
}

# Определяем, что импортировать: один файл или все
if [ -n "$1" ]; then
  # Импортируем только указанный файл
  SPECIFIC_FILE="./workflows/templates/$1"

  if [ -f "$SPECIFIC_FILE" ]; then
    echo "Импорт одного шаблона workflow..."
    import_template "$SPECIFIC_FILE"
  else
    echo "ОШИБКА: Файл $SPECIFIC_FILE не найден!"
    echo "Доступные файлы workflow:"
    ls -1 ./workflows/templates/*.json 2>/dev/null || echo "Нет доступных workflow в ./workflows/templates/"
    exit 1
  fi
else
  # Импортируем все шаблоны
  echo "Импорт всех шаблонов workflows..."

  # Проверяем наличие файлов
  TEMPLATES=$(find ./workflows/templates -name "*.json" 2>/dev/null)
  if [ -z "$TEMPLATES" ]; then
    echo "ОШИБКА: Нет JSON файлов в директории ./workflows/templates/"
    exit 1
  fi

  # Импортируем каждый шаблон
  for template in ./workflows/templates/*.json; do
    if [ -f "$template" ]; then
      import_template "$template"
    fi
  done
fi

echo "Импорт завершен!"