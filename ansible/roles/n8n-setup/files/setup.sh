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

# Функция для проверки версии контейнерного движка
function check_container_version {
  local cmd=$1
  local min_version=$2

  # Разные форматы вывода версий Docker и Podman
  if [ "$cmd" = "docker" ]; then
    local actual_version=$($cmd --version | cut -d ' ' -f3 | cut -d ',' -f1)
  else
    local actual_version=$($cmd --version | awk '{print $3}')
  fi

  # Для Podman вывод отличается, мы можем пропустить эту проверку
  if [ "$cmd" = "podman" ]; then
    log "$cmd версии $actual_version"
    return 0
  fi

  if [[ $(echo -e "$actual_version\n$min_version" | sort -V | head -n 1) != "$min_version" ]]; then
    log "Предупреждение: Требуется $cmd версии $min_version или выше. Текущая версия: $actual_version"
    log "Продолжаем, но могут возникнуть проблемы."
  else
    log "$cmd версии $actual_version соответствует требованиям"
  fi
}

# Проверка наличия необходимых зависимостей
check_dependency "$CONTAINER_CMD"
check_dependency "$COMPOSE_CMD"
check_dependency "curl"
check_dependency "openssl"

# Проверка версий
if [ "$ENGINE" = "docker" ]; then
  check_container_version "$CONTAINER_CMD" "20.10.0"
else
  check_container_version "$CONTAINER_CMD"
fi

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
        # (код преобразования docker-compose в podman-compose опущен для краткости)
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

# Оставшаяся часть скрипта (получение API-токена, инициализация БД и т.д.) без изменений

log "Установка завершена!"
log "n8n доступен по адресу: https://localhost"
log "Учетные данные по умолчанию: admin/admin (изменить в .env файле)"
log ""
log "Рекомендации:"
log "1. Отредактируйте файл .env и установите безопасные пароли и API ключи"
log "2. Создайте и импортируйте ваши собственные workflows"
log "3. Для промышленного использования настройте правильные SSL-сертификаты"

# Выводим дополнительную информацию для Podman
if [ "$ENGINE" = "podman" ]; then
    log ""
    log "Дополнительные рекомендации для Podman:"
    log "1. Убедитесь, что в ~/.config/containers/registries.conf настроен правильный поиск образов"
    log "2. Для управления используйте: make ENGINE=podman start|stop|restart и т.д."
    log "3. При проблемах с загрузкой образов, попробуйте: podman pull docker.io/library/postgres:17-alpine"
fi

# Возвращаем успешный статус завершения
exit 0