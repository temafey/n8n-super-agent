#!/bin/bash

# Скрипт для ротации и архивирования логов
# Рекомендуется запускать ежедневно через cron

# Директории для логов
LOG_DIRS=(
  "logs/n8n"
  "logs/zep"
  "logs/postgres"
  "logs/postgres-zep"
  "logs/nginx"
  "logs/redis"
  "logs/weaviate"
)

# Создаем директории для логов, если они не существуют
for dir in "${LOG_DIRS[@]}"; do
  mkdir -p "$dir"
done

# Функция для ротации логов в директории
rotate_logs_in_dir() {
  local dir=$1
  local max_size=$2  # в МБ
  local max_age=$3   # в днях
  
  echo "Обработка директории: $dir"
  
  # Ротация больших файлов
  find "$dir" -type f -name "*.log" -size +"$max_size"M | while read log; do
    timestamp=$(date +%Y%m%d-%H%M%S)
    echo "Ротация файла: $log (больше $max_size МБ)"
    mv "$log" "${log%.log}-${timestamp}.log"
    gzip "${log%.log}-${timestamp}.log"
  done
  
  # Удаление старых архивов
  find "$dir" -type f -name "*.gz" -mtime +"$max_age" | while read old_log; do
    echo "Удаление старого архива: $old_log (старше $max_age дней)"
    rm "$old_log"
  done
}

# Ротация логов для каждой директории
# Параметры: директория, максимальный размер в МБ, максимальный возраст в днях
rotate_logs_in_dir "logs/n8n" 50 30
rotate_logs_in_dir "logs/zep" 50 30
rotate_logs_in_dir "logs/postgres" 100 30
rotate_logs_in_dir "logs/postgres-zep" 100 30
rotate_logs_in_dir "logs/nginx" 50 30
rotate_logs_in_dir "logs/redis" 20 30
rotate_logs_in_dir "logs/weaviate" 50 30

echo "Ротация логов завершена!"
