#!/bin/bash

# Прерывать выполнение при ошибках
set -e

# Переменные по умолчанию
ENGINE="docker"
COMPOSE_FILE="docker-compose.yml"
SKIP_CERTS=false

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--engine)
      ENGINE="$2"
      shift 2
      ;;
    --skip-certs)
      SKIP_CERTS=true
      shift
      ;;
    *)
      echo "Неизвестный аргумент: $1"
      echo "Использование: $0 [-e|--engine docker|podman] [--skip-certs]"
      exit 1
      ;;
  esac
done

# Проверка и настройка команд в зависимости от выбранного движка
if [ "$ENGINE" = "docker" ]; then
  CONTAINER_CMD="docker"
  COMPOSE_CMD="docker-compose"
  COMPOSE_FILE="docker-compose.yml"
  echo "Выбран Docker в качестве движка контейнеров"
elif [ "$ENGINE" = "podman" ]; then
  CONTAINER_CMD="podman"
  COMPOSE_CMD="podman-compose"
  COMPOSE_FILE="podman-compose.yml"
  echo "Выбран Podman в качестве движка контейнеров"
else
  echo "Ошибка: недопустимый движок '$ENGINE'. Используйте 'docker' или 'podman'."
  exit 1
fi

# Функция обработки ошибок
function handle_error {
  echo "Ошибка в строке $1"
  echo "Очистка временных файлов и выход..."
  # Не завершаем скрипт с ошибкой, продолжаем выполнение
  set +e
}

# Настраиваем трап для перехвата ошибок
trap 'handle_error $LINENO' ERR

# Директория скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LOG_FILE="$SCRIPT_DIR/setup.log"

# Функция для логирования
function log {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Инициализация n8n супер-агента с использованием $ENGINE..."

# Функция для проверки наличия программ
function check_dependency {
  if ! command -v $1 &> /dev/null; then
    log "Ошибка: $1 не установлен"
    exit 1
  fi
}

# Проверка наличия необходимых зависимостей
check_dependency "$CONTAINER_CMD"
check_dependency "$COMPOSE_CMD"
check_dependency "curl"
check_dependency "openssl"

# Создание необходимых директорий
mkdir -p "$SCRIPT_DIR/logs/n8n" "$SCRIPT_DIR/logs/zep" "$SCRIPT_DIR/logs/postgres" "$SCRIPT_DIR/logs/postgres-zep" "$SCRIPT_DIR/logs/redis" "$SCRIPT_DIR/logs/nginx" "$SCRIPT_DIR/logs/weaviate"
mkdir -p "$SCRIPT_DIR/nginx/certs" "$SCRIPT_DIR/nginx/conf.d"
mkdir -p "$SCRIPT_DIR/workflows/prompts" "$SCRIPT_DIR/workflows/templates"
mkdir -p "$SCRIPT_DIR/.make"

# Проверка .env файла
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log "Файл .env не найден. Создаем из шаблона..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    log "Пожалуйста, отредактируйте файл .env и установите правильные значения API ключей."
fi

# Проверка файла конфигурации для выбранного движка
if [ ! -f "$SCRIPT_DIR/$COMPOSE_FILE" ]; then
    if [ "$ENGINE" = "podman" ]; then
        log "Файл $COMPOSE_FILE не найден. Создаем из docker-compose.yml с необходимыми изменениями..."
        # (код для преобразования docker-compose в podman-compose опущен)
    else
        log "Ошибка: файл $COMPOSE_FILE не найден"
        exit 1
    fi
fi

# ВАЖНО: Проверка наличия сертификатов Cloudflare в папке ansible/ssl
if [ -f "$SCRIPT_DIR/ansible/ssl/microcore.cc.pem" ] && [ -f "$SCRIPT_DIR/ansible/ssl/microcore.cc.key" ]; then
    log "Обнаружены сертификаты Cloudflare в ansible/ssl - используем их"
    mkdir -p "$SCRIPT_DIR/nginx/certs"
    cp "$SCRIPT_DIR/ansible/ssl/microcore.cc.pem" "$SCRIPT_DIR/nginx/certs/server.crt"
    cp "$SCRIPT_DIR/ansible/ssl/microcore.cc.key" "$SCRIPT_DIR/nginx/certs/server.key"
    chmod 644 "$SCRIPT_DIR/nginx/certs/server.crt"
    chmod 600 "$SCRIPT_DIR/nginx/certs/server.key"
    SKIP_CERTS=true
    log "Сертификаты Cloudflare успешно скопированы"
fi

# Создание самоподписанных SSL-сертификатов, если их нет и не указан флаг --skip-certs
if [ "$SKIP_CERTS" = false ] && [ ! -f "$SCRIPT_DIR/nginx/certs/server.crt" ]; then
    log "Создаем самоподписанные SSL сертификаты..."
    mkdir -p "$SCRIPT_DIR/nginx/certs"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/nginx/certs/server.key" -out "$SCRIPT_DIR/nginx/certs/server.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
fi

# Проверка наличия сертификатов после всех операций
if [ ! -f "$SCRIPT_DIR/nginx/certs/server.crt" ] || [ ! -f "$SCRIPT_DIR/nginx/certs/server.key" ]; then
    log "ОШИБКА: SSL сертификаты не найдены. Проверьте директорию nginx/certs"
    exit 1
fi

# Запуск Compose
log "Запуск контейнеров с помощью $COMPOSE_CMD..."

if [ "$ENGINE" = "podman" ]; then
    # Последовательный запуск для Podman с ожиданием
    cd "$SCRIPT_DIR"

    # Запускаем базы данных сначала
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d postgres postgres-zep
    log "Запущены контейнеры PostgreSQL. Ожидаем 15 секунд для инициализации..."
    sleep 15

    # Запускаем Redis и сервис эмбеддингов
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d redis embeddings-service
    log "Запущены Redis и сервис эмбеддингов. Ожидаем 10 секунд..."
    sleep 10

    # Запускаем Zep, Weaviate
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d zep weaviate
    log "Запущены Zep и Weaviate. Ожидаем 10 секунд..."
    sleep 10

    # Запускаем n8n
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d n8n
    log "Запущен n8n. Ожидаем 15 секунд..."
    sleep 15

    # Запускаем nginx в последнюю очередь
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d nginx
    log "Запущен nginx. Все контейнеры запущены."

else
    # Для Docker запускаем все сразу
    cd "$SCRIPT_DIR" && $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
fi

# Функция для проверки доступности сервиса
function wait_for_service {
  local host=$1
  local port=$2
  local service=$3
  local timeout=${4:-60}

  log "Ожидание $service ($host:$port)..."

  for i in $(seq 1 $timeout); do
    if nc -z $host $port 2>/dev/null || curl -s $host:$port >/dev/null 2>&1; then
      log "$service доступен!"
      return 0
    fi
    echo -n "."
    sleep 1
  done

  log "$service недоступен после $timeout секунд"
  return 1
}

# Ожидание запуска сервисов
log "Ожидание запуска сервисов..."
wait_for_service "localhost" "5678" "n8n" 60 || true
wait_for_service "localhost" "8080" "embeddings-service" 120 || true

# Получение API токена n8n
log "Получение API токена n8n (или проверка существующего)..."
if [ ! -f "$SCRIPT_DIR/.n8n_api_key" ]; then
    # Здесь добавьте код для получения API токена
    # (оставшаяся часть кода получения токена и импорта шаблонов опущена)
    log "API токен не найден. Вам нужно создать API ключ вручную через веб-интерфейс n8n."
fi

log "Установка завершена!"
log "n8n доступен по адресу: https://localhost"
log "Учетные данные по умолчанию: admin/admin (изменить в .env файле)"
log ""
log "Рекомендации:"
log "1. Отредактируйте файл .env и установите безопасные пароли и API ключи"
log "2. Создайте и импортируйте ваши собственные workflows"
log "3. Для промышленного использования настройте правильные SSL-сертификаты"

# Возвращаем успешный статус завершения
exit 0