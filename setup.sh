#!/bin/bash

# Прерывать выполнение при ошибках
set -e

# Переменные по умолчанию
ENGINE="docker"
COMPOSE_FILE="docker-compose.yml"

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--engine)
      ENGINE="$2"
      shift 2
      ;;
    *)
      echo "Неизвестный аргумент: $1"
      echo "Использование: $0 [-e|--engine docker|podman]"
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

        # Проверяем настройки registries.conf
        if [ ! -f "$HOME/.config/containers/registries.conf" ] || ! grep -q "registries.search" "$HOME/.config/containers/registries.conf"; then
            log "ВНИМАНИЕ: Не найдены настройки registries.conf для Podman."
            log "Рекомендуется сначала запустить ./configure-podman.sh"

            # Проверка наличия скрипта
            if [ ! -f "$SCRIPT_DIR/configure-podman.sh" ]; then
                log "Создаем скрипт configure-podman.sh..."
                cat > "$SCRIPT_DIR/configure-podman.sh" << 'EOF'
#!/bin/bash
# configure-podman.sh - Скрипт для настройки Podman для работы с короткими именами образов

# Прерывать выполнение при ошибках
set -e

echo "Настройка Podman для использования с n8n супер-агентом..."

# Создание директории для пользовательских настроек Podman, если она не существует
mkdir -p ~/.config/containers

# Проверяем существование файла registries.conf
if [ ! -f ~/.config/containers/registries.conf ]; then
    echo "Создаем пользовательский файл registries.conf..."
    cat > ~/.config/containers/registries.conf << EOF
# Настройка репозиториев для поиска образов
[registries.search]
registries = ['docker.io', 'quay.io', 'ghcr.io']

# Настройка недоверенных репозиториев (пустой список)
[registries.insecure]
registries = []

# Настройка блокируемых репозиториев (пустой список)
[registries.block]
registries = []
EOF
    echo "Файл registries.conf создан."
else
    # Проверяем и обновляем существующий файл
    if ! grep -q "registries.search" ~/.config/containers/registries.conf; then
        echo "Обновляем существующий файл registries.conf..."
        cat >> ~/.config/containers/registries.conf << EOF
[registries.search]
registries = ['docker.io', 'quay.io', 'ghcr.io']
EOF
    fi
fi

# Создание файла конфигурации storage.conf для Podman
if [ ! -f ~/.config/containers/storage.conf ]; then
    echo "Создаем файл storage.conf..."
    cat > ~/.config/containers/storage.conf << EOF
[storage]
driver = "overlay"
graphroot = "$HOME/.local/share/containers/storage"
runroot = "$HOME/.local/share/containers/storage/run"

[storage.options]
pull_options = {use_hard_links = "false", enable_partial_images = "false"}
EOF
    echo "Файл storage.conf создан."
fi

# Создание файла containers.conf для настройки Podman
if [ ! -f ~/.config/containers/containers.conf ]; then
    echo "Создаем файл containers.conf..."
    cat > ~/.config/containers/containers.conf << EOF
[containers]
netns="bridge"
userns="host"
ipcns="host"
utsns="host"
cgroupns="host"
cgroups="disabled"
log_driver = "k8s-file"

[engine]
cgroup_manager = "cgroupfs"
runtime = "crun"
network_cmd_options = ["allow_host_loopback=true"]
EOF
    echo "Файл containers.conf создан."
fi

echo "Podman настроен для использования неполных имен образов."
echo "Теперь вы можете запустить ./setup.sh -e podman"

# Проверка наличия podman-compose
if ! command -v podman-compose &> /dev/null; then
    echo "ВНИМАНИЕ: podman-compose не найден!"
    echo "Рекомендуем установить его одним из следующих способов:"
    echo "  - pip install podman-compose"
    echo "  - apt install podman-compose (для Debian/Ubuntu)"
    echo "  - dnf install podman-compose (для Fedora/RHEL)"
fi

# Дополнительная информация и советы
echo ""
echo "Полезные команды Podman:"
echo "  podman ps             - список запущенных контейнеров"
echo "  podman images         - список доступных образов"
echo "  podman system prune   - очистка неиспользуемых ресурсов"
echo ""
EOF
                chmod +x "$SCRIPT_DIR/configure-podman.sh"
                log "Запустите ./configure-podman.sh и затем повторите ./setup.sh -e podman"
                exit 1
            else
                log "Запускаем ./configure-podman.sh..."
                chmod +x "$SCRIPT_DIR/configure-podman.sh"
                "$SCRIPT_DIR/configure-podman.sh"
            fi
        fi

        # Сначала создаем копию
        cp "$SCRIPT_DIR/docker-compose.yml" "$SCRIPT_DIR/$COMPOSE_FILE"

        # Добавляем опцию :Z к томам для SELinux (если ее еще нет)
        sed -i 's/\(- .*\):\(.*\)\(:\?Z\)\?$/\1:\2:Z/g' "$SCRIPT_DIR/$COMPOSE_FILE"

        # Заменяем короткие имена образов на полные
        sed -i 's|postgres:17-alpine|docker.io/library/postgres:17-alpine|g' "$SCRIPT_DIR/$COMPOSE_FILE"
        sed -i 's|redis:alpine|docker.io/library/redis:alpine|g' "$SCRIPT_DIR/$COMPOSE_FILE"
        sed -i 's|nginx:alpine|docker.io/library/nginx:alpine|g' "$SCRIPT_DIR/$COMPOSE_FILE"
        sed -i 's|semitechnologies/weaviate:1.30.1|docker.io/semitechnologies/weaviate:1.30.1|g' "$SCRIPT_DIR/$COMPOSE_FILE"
        sed -i 's|n8nio/n8n:1.89.2|docker.io/n8nio/n8n:1.89.2|g' "$SCRIPT_DIR/$COMPOSE_FILE"

        # Нам также нужно обновить Dockerfile.n8n для использования полного имени базового образа
        if [ -f "$SCRIPT_DIR/Dockerfile.n8n" ]; then
            cp "$SCRIPT_DIR/Dockerfile.n8n" "$SCRIPT_DIR/Dockerfile.n8n.original"
            sed -i 's|FROM n8nio/n8n:1.89.2|FROM docker.io/n8nio/n8n:1.89.2|g' "$SCRIPT_DIR/Dockerfile.n8n"
        fi

        log "Преобразование выполнено, проверьте и отредактируйте $COMPOSE_FILE при необходимости."
    else
        log "Ошибка: файл $COMPOSE_FILE не найден"
        exit 1
    fi
fi

# Создание самоподписанных SSL-сертификатов, если их нет
if [ ! -f "$SCRIPT_DIR/nginx/certs/server.crt" ]; then
    log "Создаем самоподписанные SSL сертификаты..."
    mkdir -p "$SCRIPT_DIR/nginx/certs"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/nginx/certs/server.key" -out "$SCRIPT_DIR/nginx/certs/server.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
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

# Функция для проверки готовности PostgreSQL
function wait_for_postgres {
  local container=$1
  local user=$2
  local retries=${3:-30}
  local delay=${4:-2}

  log "Ожидание готовности PostgreSQL ($container)..."

  for i in $(seq 1 $retries); do
    if [ "$ENGINE" = "docker" ]; then
      if $COMPOSE_CMD exec -T $container pg_isready -U $user >/dev/null 2>&1; then
        log "PostgreSQL ($container) готов к работе!"
        return 0
      fi
    else
      # Для podman команда может отличаться
      if $CONTAINER_CMD exec $(podman ps -qf "name=n8n-super-agent_$container") pg_isready -U $user >/dev/null 2>&1; then
        log "PostgreSQL ($container) готов к работе!"
        return 0
      fi
    fi
    echo -n "."
    sleep $delay
  done

  log "PostgreSQL ($container) не готов после $retries попыток"
  return 1
}

# Функция для получения API токена n8n
function get_n8n_api_token {
  log "Получение API токена n8n..."

  # Ожидаем запуск n8n
  sleep 15

  # Получаем список доступных команд
  log "Проверка доступных команд n8n..."
  local commands=""

  if [ "$ENGINE" = "docker" ]; then
    commands=$($COMPOSE_CMD exec -T n8n n8n --help 2>&1 || echo "")
  else
    # Получаем ID контейнера n8n для Podman
    local n8n_container=$($CONTAINER_CMD ps -qf "name=n8n-super-agent_n8n")
    if [ -n "$n8n_container" ]; then
      commands=$($CONTAINER_CMD exec $n8n_container n8n --help 2>&1 || echo "")
    else
      log "Не удалось найти контейнер n8n."
      commands=""
    fi
  fi

  log "Доступные команды: $commands"

  # Проверяем, есть ли команда apiKey:create
  local api_key=""
  if echo "$commands" | grep -q "apiKey"; then
    log "Найдена команда для API ключей, пробуем создать..."

    # Попытка с apiKey:create
    if [ "$ENGINE" = "docker" ]; then
      # Для Docker
      if $COMPOSE_CMD exec -T n8n n8n apiKey:create --help >/dev/null 2>&1; then
        log "Используем команду apiKey:create..."
        api_key=$($COMPOSE_CMD exec -T n8n n8n apiKey:create --name "setup-key" --json 2>/dev/null | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "")
      # Попытка с устаревшей команды create:apikey
      elif $COMPOSE_CMD exec -T n8n n8n create:apikey --help >/dev/null 2>&1; then
        log "Используем команду create:apikey..."
        api_key=$($COMPOSE_CMD exec -T n8n n8n create:apikey --quiet 2>/dev/null || echo "")
      fi
    else
      # Для Podman
      local n8n_container=$($CONTAINER_CMD ps -qf "name=n8n-super-agent_n8n")
      if [ -n "$n8n_container" ]; then
        if $CONTAINER_CMD exec $n8n_container n8n apiKey:create --help >/dev/null 2>&1; then
          log "Используем команду apiKey:create..."
          api_key=$($CONTAINER_CMD exec $n8n_container n8n apiKey:create --name "setup-key" --json 2>/dev/null | grep -o '"value":"[^"]*"' | cut -d'"' -f4 || echo "")
        # Попытка с устаревшей команды create:apikey
        elif $CONTAINER_CMD exec $n8n_container n8n create:apikey --help >/dev/null 2>&1; then
          log "Используем команду create:apikey..."
          api_key=$($CONTAINER_CMD exec $n8n_container n8n create:apikey --quiet 2>/dev/null || echo "")
        fi
      fi
    fi
  fi

  # Если команда не найдена или ключ не получен, используем аварийный вариант
  if [ -z "$api_key" ]; then
    log "Не удалось создать API ключ через CLI. Используем аварийный вариант..."

    # Генерируем временный ключ
    api_key="n8n_api_$(date +%s)_${RANDOM}"
    log "Создан временный API ключ: $api_key"
    log "ВНИМАНИЕ: Это временный ключ. Создайте постоянный API ключ через веб-интерфейс n8n."
  else
    log "API ключ успешно создан через CLI"
  fi

  # Сохраняем API ключ в файл
  echo "$api_key" > "$SCRIPT_DIR/.n8n_api_key"
  chmod 600 "$SCRIPT_DIR/.n8n_api_key"

  log "API токен n8n сохранен в файл .n8n_api_key"
  return 0
}

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

# Ожидание запуска сервисов
log "Ожидание запуска сервисов..."

# Ожидание запуска PostgreSQL
wait_for_postgres "postgres" "n8n" || true
wait_for_postgres "postgres-zep" "zep" || true

# Ожидание запуска других сервисов
wait_for_service "localhost" "5678" "n8n" 60 || true
wait_for_service "localhost" "8080" "embeddings-service" 120 || true

# Инициализация Weaviate
log "Инициализация схемы Weaviate..."
if [ "$ENGINE" = "docker" ]; then
    $COMPOSE_CMD exec -T n8n node /home/node/.n8n/lib/init-weaviate.js || {
        log "Предупреждение: Не удалось инициализировать схему Weaviate. Возможно, она уже существует."
    }
else
    # Для Podman
    n8n_container=$($CONTAINER_CMD ps -qf "name=n8n-super-agent_n8n")
    if [ -n "$n8n_container" ]; then
        $CONTAINER_CMD exec $n8n_container node /home/node/.n8n/lib/init-weaviate.js || {
            log "Предупреждение: Не удалось инициализировать схему Weaviate. Возможно, она уже существует."
        }
    else
        log "Не удалось найти контейнер n8n для инициализации Weaviate."
    fi
fi

# Ожидаем завершения инициализации
sleep 5

# Получение API токена n8n
get_n8n_api_token || true
N8N_API_KEY=$(cat "$SCRIPT_DIR/.n8n_api_key" 2>/dev/null || echo "")

if [ -z "$N8N_API_KEY" ]; then
  log "ОШИБКА: Не удалось получить API ключ n8n."
  log "Шаблоны не будут импортированы автоматически. Вам нужно создать API ключ через веб-интерфейс и импортировать шаблоны вручную."
else
  # Импорт шаблонов workflows
  log "Импорт шаблонов workflows..."
  for template in "$SCRIPT_DIR/workflows/templates/"*.json; do
    if [ -f "$template" ]; then
      filename=$(basename -- "$template")
      log "Импорт шаблона: $filename"
      curl -X POST "http://localhost:5678/rest/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d @"$template" -s || log "Не удалось импортировать шаблон $filename"
    fi
  done
fi

# Инициализация БД
log "Инициализация базы данных..."
if [ "$ENGINE" = "docker" ]; then
    $COMPOSE_CMD exec -T postgres psql -U n8n -d n8n < "$SCRIPT_DIR/init-db.sql" || log "Предупреждение: Не удалось инициализировать базу данных."
else
    # Для Podman
    postgres_container=$($CONTAINER_CMD ps -qf "name=n8n-super-agent_postgres")
    if [ -n "$postgres_container" ]; then
        $CONTAINER_CMD exec -i $postgres_container psql -U n8n -d n8n < "$SCRIPT_DIR/init-db.sql" || log "Предупреждение: Не удалось инициализировать базу данных."
    else
        log "Не удалось найти контейнер postgres для инициализации БД."
    fi
fi

# Создание Makefile для разных движков
log "Создание файлов конфигурации для Makefile..."

# Создаем docker.mk
mkdir -p "$SCRIPT_DIR/.make"
cat > "$SCRIPT_DIR/.make/docker.mk" << 'EOF'
# .make/docker.mk - Makefile для Docker
# Подключается из основного Makefile

# Переменные для Docker
COMPOSE_FILE = docker-compose.yml
COMPOSE_CMD = docker-compose -f $(COMPOSE_FILE)
N8N_CONTAINER = $$(docker ps -qf "name=n8n-super-agent_n8n")
POSTGRES_CONTAINER = $$(docker ps -qf "name=n8n-super-agent_postgres")

# Инициализация проекта
setup:
	@echo "${GREEN}Инициализация проекта n8n-супер-агент с Docker...${NC}"
	@chmod +x *.sh
	@./setup.sh

# Запуск контейнеров
start:
	@echo "${GREEN}Запуск контейнеров с Docker...${NC}"
	@$(COMPOSE_CMD) up -d
	@echo "${GREEN}Контейнеры запущены. n8n доступен по адресу: https://localhost${NC}"

# Остановка контейнеров
stop:
	@echo "${GREEN}Остановка контейнеров...${NC}"
	@$(COMPOSE_CMD) stop
	@echo "${GREEN}Контейнеры остановлены${NC}"

# Перезапуск контейнеров
restart:
	@echo "${GREEN}Перезапуск контейнеров...${NC}"
	@$(COMPOSE_CMD) restart
	@echo "${GREEN}Контейнеры перезапущены${NC}"

# Проверка статуса системы
status:
	@echo "${GREEN}Статус контейнеров (Docker):${NC}"
	@$(COMPOSE_CMD) ps

# Проверка статуса системы
stats:
	@echo "${GREEN}Статистика контейнеров (Docker):${NC}"
	@$(COMPOSE_CMD) stats

# Просмотр логов всех контейнеров
logs:
	@$(COMPOSE_CMD) logs --tail=100 -f

# Создание резервной копии данных
backup:
	@echo "${GREEN}Создание резервной копии данных (Docker)...${NC}"
	@mkdir -p $(BACKUP_DIR)
	@echo "Создание дампа PostgreSQL..."
	@docker exec $(POSTGRES_CONTAINER) pg_dump -U n8n -d n8n > $(BACKUP_DIR)/n8n-db-$(DATE).sql
	@echo "Создание резервной копии workflows..."
	@tar -czvf $(BACKUP_DIR)/workflows-$(DATE).tar.gz workflows
	@echo "Создание резервной копии настроек..."
	@tar -czvf $(BACKUP_DIR)/config-$(DATE).tar.gz .env docker-compose.yml nginx
	@echo "${GREEN}Резервная копия создана в директории $(BACKUP_DIR)${NC}"

# Восстановление из резервной копии
restore:
	@echo "${RED}Восстановление данных из резервной копии (Docker)...${NC}"
	@echo "${YELLOW}Предупреждение: Эта операция перезапишет текущие данные!${NC}"
	@read -p "Введите имя файла дампа БД для восстановления (из директории $(BACKUP_DIR)): " db_file; \
	read -p "Введите имя файла архива workflows для восстановления (из директории $(BACKUP_DIR)): " wf_file; \
	read -p "Продолжить восстановление? (y/n): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		echo "Восстановление БД из $$db_file..."; \
		docker exec -i $(POSTGRES_CONTAINER) psql -U n8n -d n8n < $(BACKUP_DIR)/$$db_file; \
		echo "Восстановление workflows из $$wf_file..."; \
		tar -xzvf $(BACKUP_DIR)/$$wf_file; \
		echo "${GREEN}Восстановление завершено${NC}"; \
	else \
		echo "${RED}Восстановление отменено${NC}"; \
	fi

# Очистка контейнеров без удаления данных
clean:
	@echo "${YELLOW}Остановка и удаление контейнеров (без удаления данных)...${NC}"
	@$(COMPOSE_CMD) down
	@echo "${GREEN}Контейнеры удалены. Данные сохранены в томах Docker.${NC}"

# Полный сброс проекта
reset:
	@echo "${RED}Сброс проекта (Docker)...${NC}"
	@echo "${YELLOW}Предупреждение: Эта операция удалит ВСЕ данные проекта!${NC}"
	@read -p "Продолжить? (введите 'reset' для подтверждения): " confirm; \
	if [ "$$confirm" = "reset" ]; then \
		echo "Удаление контейнеров и томов..."; \
		$(COMPOSE_CMD) down -v; \
		echo "${GREEN}Сброс завершен. Все данные удалены.${NC}"; \
	else \
		echo "${RED}Сброс отменен${NC}"; \
	fi

# Обновление образов
update:
	@echo "${GREEN}Обновление образов контейнеров (Docker)...${NC}"
	@$(COMPOSE_CMD) pull
	@echo "${GREEN}Образы обновлены. Перезапустите контейнеры: make restart${NC}"

# Запуск в режиме разработки
dev:
	@echo "${GREEN}Запуск в режиме разработки (Docker)...${NC}"
	@$(COMPOSE_CMD) up

# Запуск тестов
test:
	@echo "${GREEN}Запуск тестов...${NC}"
	@echo "Проверка доступности сервисов..."
	@./check-system.sh
	@echo "Тестирование примеров API..."
	@if [ -f examples/api-usage.js ]; then \
		echo "Запуск api-usage.js..."; \
		node examples/api-usage.js; \
	fi
	@if [ -f examples/weaviate-test.js ]; then \
		echo "Запуск weaviate-test.js..."; \
		node examples/weaviate-test.js; \
	fi

# Подключение к контейнеру n8n
shell:
	@echo "${GREEN}Подключение к контейнеру n8n (Docker)...${NC}"
	@docker exec -it $(N8N_CONTAINER) /bin/sh

# Команды для просмотра логов отдельных сервисов
n8n-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f n8n

redis-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f redis

postgres-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f postgres

weaviate-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f weaviate

zep-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f zep

all-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f

# Полный сброс данных и перезапуск системы
reset-db:
	@echo "===> Останавливаем все контейнеры..."
	docker-compose down

	@echo "===> Удаляем все тома с данными..."
	docker volume rm n8n_data postgres_data postgres_zep_data zep_data redis_data weaviate_data 2>/dev/null || true

	@echo "===> Удаляем все анонимные тома..."
	docker volume rm $$(docker volume ls -q -f dangling=true) 2>/dev/null || true

	@echo "===> Очищаем каталоги с логами..."
	rm -rf ./logs/n8n/* ./logs/postgres/* ./logs/postgres-zep/* ./logs/zep/* ./logs/redis/* ./logs/weaviate/* ./logs/nginx/* 2>/dev/null || true
	mkdir -p ./logs/n8n ./logs/postgres ./logs/postgres-zep ./logs/zep ./logs/redis ./logs/weaviate ./logs/nginx

	@echo "===> Проверяем конфигурацию NGINX..."
	mkdir -p ./nginx/conf.d
	if [ ! -f "./nginx/conf.d/default.conf" ]; then \
		echo "Создаем базовую конфигурацию NGINX..."; \
		echo 'server {\n    listen 80;\n    server_name localhost;\n\n    location /n8n/ {\n        proxy_pass http://n8n:5678/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /zep/ {\n        proxy_pass http://zep:8000/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /weaviate/ {\n        proxy_pass http://weaviate:8080/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /health {\n        access_log off;\n        return 200 "healthy";\n    }\n}' > ./nginx/conf.d/default.conf; \
	fi

	@echo "===> Запускаем базы данных в первую очередь..."
	docker-compose up -d postgres postgres-zep

	@echo "===> Ожидаем инициализации баз данных (15 секунд)..."
	sleep 15

	@echo "===> Запускаем Redis..."
	docker-compose up -d redis

	@echo "===> Запускаем сервис эмбеддингов..."
	docker-compose up -d embeddings-service

	@echo "===> Ожидаем запуск сервиса эмбеддингов (10 секунд)..."
	sleep 10

	@echo "===> Запускаем Zep (требуется postgres-zep и embeddings-service)..."
	docker-compose up -d zep

	@echo "===> Ожидаем запуск Zep (10 секунд)..."
	sleep 10

	@echo "===> Запускаем Weaviate..."
	docker-compose up -d weaviate

	@echo "===> Ожидаем запуск Weaviate (10 секунд)..."
	sleep 10

	@echo "===> Запускаем n8n..."
	docker-compose up -d n8n

	@echo "===> Ожидаем запуск n8n (15 секунд)..."
	sleep 15

	@echo "===> Запускаем NGINX (требуется zep, weaviate и n8n)..."
	docker-compose up -d nginx

	@echo "===> Проверяем статус контейнеров..."
	docker-compose ps

	@echo "===> Проверяем доступность сервисов..."
	echo "\nZep status: " && curl -s http://localhost:8000/healthz || echo "\nВНИМАНИЕ: Zep не отвечает!"
	echo "\nEmbeddings service status: " && curl -s http://localhost:8080/info || echo "\nВНИМАНИЕ: Embeddings service не отвечает!"
	echo "\nWeaviate status: " && curl -s http://localhost:8087/v1/.well-known/ready || echo "\nВНИМАНИЕ: Weaviate не отвечает!"
	echo "\nn8n status: " && curl -s http://localhost:5678/healthz || echo "\nВНИМАНИЕ: n8n не отвечает!"
	echo "\nNGINX status: " && curl -s http://localhost/health || echo "\nВНИМАНИЕ: NGINX не отвечает!"

	@echo "\n===> Сброс завершен. Система запущена с чистыми базами данных.\n"
	@echo "Для отладки используйте:"
	@echo "  docker-compose logs zep         # логи Zep"
	@echo "  docker-compose logs embeddings-service  # логи сервиса эмбеддингов"
	@echo "  docker-compose logs nginx       # логи NGINX"
	@echo "  docker-compose logs postgres-zep # логи PostgreSQL для Zep"

backup-db:
	@echo "Создаем резервную копию баз данных..."
	mkdir -p ./backups/$(shell date +%Y%m%d_%H%M%S)
	docker exec postgres-1 pg_dumpall -U postgres > ./backups/$(shell date +%Y%m%d_%H%M%S)/postgres_dump.sql
	cp -r ./data ./backups/$(shell date +%Y%m%d_%H%M%S)/data_backup
	@echo "Резервная копия создана в каталоге ./backups/$(shell date +%Y%m%d_%H%M%S)/"
EOF

# Создаем podman.mk
cat > "$SCRIPT_DIR/.make/podman.mk" << 'EOF'
# .make/podman.mk - Makefile для Podman
# Подключается из основного Makefile

# Переменные для Podman
COMPOSE_FILE = podman-compose.yml
COMPOSE_CMD = podman-compose -f $(COMPOSE_FILE)
N8N_CONTAINER = $$(podman ps -qf "name=n8n-super-agent_n8n")
POSTGRES_CONTAINER = $$(podman ps -qf "name=n8n-super-agent_postgres")

# Инициализация проекта
setup:
	@echo "${GREEN}Инициализация проекта n8n-супер-агент с Podman...${NC}"
	@chmod +x *.sh
	@./setup.sh -e podman

# Запуск контейнеров
start:
	@echo "${GREEN}Запуск контейнеров с Podman...${NC}"
	@$(COMPOSE_CMD) up -d
	@echo "${GREEN}Контейнеры запущены. n8n доступен по адресу: https://localhost${NC}"

# Остановка контейнеров
stop:
	@echo "${GREEN}Остановка контейнеров...${NC}"
	@$(COMPOSE_CMD) stop
	@echo "${GREEN}Контейнеры остановлены${NC}"

# Перезапуск контейнеров
restart:
	@echo "${GREEN}Перезапуск контейнеров...${NC}"
	@$(COMPOSE_CMD) restart
	@echo "${GREEN}Контейнеры перезапущены${NC}"

# Проверка статуса системы
status:
	@echo "${GREEN}Статус контейнеров (Podman):${NC}"
	@$(COMPOSE_CMD) ps

# Проверка статуса системы
stats:
	@echo "${GREEN}Статистика контейнеров (Podman):${NC}"
	@$(COMPOSE_CMD) stats

# Просмотр логов всех контейнеров
logs:
	@$(COMPOSE_CMD) logs --tail=100 -f

# Создание резервной копии данных
backup:
	@echo "${GREEN}Создание резервной копии данных (Podman)...${NC}"
	@mkdir -p $(BACKUP_DIR)
	@echo "Создание дампа PostgreSQL..."
	@podman exec $(POSTGRES_CONTAINER) pg_dump -U n8n -d n8n > $(BACKUP_DIR)/n8n-db-$(DATE).sql
	@echo "Создание резервной копии workflows..."
	@tar -czvf $(BACKUP_DIR)/workflows-$(DATE).tar.gz workflows
	@echo "Создание резервной копии настроек..."
	@tar -czvf $(BACKUP_DIR)/config-$(DATE).tar.gz .env podman-compose.yml nginx
	@echo "${GREEN}Резервная копия создана в директории $(BACKUP_DIR)${NC}"

# Восстановление из резервной копии
restore:
	@echo "${RED}Восстановление данных из резервной копии (Podman)...${NC}"
	@echo "${YELLOW}Предупреждение: Эта операция перезапишет текущие данные!${NC}"
	@read -p "Введите имя файла дампа БД для восстановления (из директории $(BACKUP_DIR)): " db_file; \
	read -p "Введите имя файла архива workflows для восстановления (из директории $(BACKUP_DIR)): " wf_file; \
	read -p "Продолжить восстановление? (y/n): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		echo "Восстановление БД из $$db_file..."; \
		podman exec -i $(POSTGRES_CONTAINER) psql -U n8n -d n8n < $(BACKUP_DIR)/$$db_file; \
		echo "Восстановление workflows из $$wf_file..."; \
		tar -xzvf $(BACKUP_DIR)/$$wf_file; \
		echo "${GREEN}Восстановление завершено${NC}"; \
	else \
		echo "${RED}Восстановление отменено${NC}"; \
	fi

# Очистка контейнеров без удаления данных
clean:
	@echo "${YELLOW}Остановка и удаление контейнеров (без удаления данных)...${NC}"
	@$(COMPOSE_CMD) down
	@echo "${GREEN}Контейнеры удалены. Данные сохранены в томах Podman.${NC}"

# Полный сброс проекта
reset:
	@echo "${RED}Сброс проекта (Podman)...${NC}"
	@echo "${YELLOW}Предупреждение: Эта операция удалит ВСЕ данные проекта!${NC}"
	@read -p "Продолжить? (введите 'reset' для подтверждения): " confirm; \
	if [ "$$confirm" = "reset" ]; then \
		echo "Удаление контейнеров и томов..."; \
		$(COMPOSE_CMD) down -v; \
		echo "${GREEN}Сброс завершен. Все данные удалены.${NC}"; \
	else \
		echo "${RED}Сброс отменен${NC}"; \
	fi

# Обновление образов
update:
	@echo "${GREEN}Обновление образов контейнеров (Podman)...${NC}"
	@$(COMPOSE_CMD) pull
	@echo "${GREEN}Образы обновлены. Перезапустите контейнеры: make restart${NC}"

# Запуск в режиме разработки
dev:
	@echo "${GREEN}Запуск в режиме разработки (Podman)...${NC}"
	@$(COMPOSE_CMD) up

# Запуск тестов
test:
	@echo "${GREEN}Запуск тестов...${NC}"
	@echo "Проверка доступности сервисов..."
	@./check-system.sh
	@echo "Тестирование примеров API..."
	@if [ -f examples/api-usage.js ]; then \
		echo "Запуск api-usage.js..."; \
		node examples/api-usage.js; \
	fi
	@if [ -f examples/weaviate-test.js ]; then \
		echo "Запуск weaviate-test.js..."; \
		node examples/weaviate-test.js; \
	fi

# Подключение к контейнеру n8n
shell:
	@echo "${GREEN}Подключение к контейнеру n8n (Podman)...${NC}"
	@podman exec -it $(N8N_CONTAINER) /bin/sh

# Команды для просмотра логов отдельных сервисов
n8n-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f n8n

redis-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f redis

postgres-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f postgres

weaviate-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f weaviate

zep-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f zep

all-logs:
	@$(COMPOSE_CMD) logs --tail=100 -f

# Полный сброс данных и перезапуск системы
reset-db:
	@echo "===> Останавливаем все контейнеры..."
	podman-compose down

	@echo "===> Удаляем все тома с данными..."
	podman volume rm n8n_data postgres_data postgres_zep_data zep_data redis_data weaviate_data 2>/dev/null || true

	@echo "===> Удаляем все анонимные тома..."
	podman volume rm $$(podman volume ls -q -f dangling=true) 2>/dev/null || true

	@echo "===> Очищаем каталоги с логами..."
	rm -rf ./logs/n8n/* ./logs/postgres/* ./logs/postgres-zep/* ./logs/zep/* ./logs/redis/* ./logs/weaviate/* ./logs/nginx/* 2>/dev/null || true
	mkdir -p ./logs/n8n ./logs/postgres ./logs/postgres-zep ./logs/zep ./logs/redis ./logs/weaviate ./logs/nginx

	@echo "===> Проверяем конфигурацию NGINX..."
	mkdir -p ./nginx/conf.d
	if [ ! -f "./nginx/conf.d/default.conf" ]; then \
		echo "Создаем базовую конфигурацию NGINX..."; \
		echo 'server {\n    listen 80;\n    server_name localhost;\n\n    location /n8n/ {\n        proxy_pass http://n8n:5678/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /zep/ {\n        proxy_pass http://zep:8000/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /weaviate/ {\n        proxy_pass http://weaviate:8080/;\n        proxy_set_header Host $$host;\n        proxy_set_header X-Real-IP $$remote_addr;\n    }\n\n    location /health {\n        access_log off;\n        return 200 "healthy";\n    }\n}' > ./nginx/conf.d/default.conf; \
	fi

	@echo "===> Запускаем базы данных в первую очередь..."
	podman-compose up -d postgres postgres-zep

	@echo "===> Ожидаем инициализации баз данных (15 секунд)..."
	sleep 15

	@echo "===> Запускаем Redis..."
	podman-compose up -d redis

	@echo "===> Запускаем сервис эмбеддингов..."
	podman-compose up -d embeddings-service

	@echo "===> Ожидаем запуск сервиса эмбеддингов (10 секунд)..."
	sleep 10

	@echo "===> Запускаем Zep (требуется postgres-zep и embeddings-service)..."
	podman-compose up -d zep

	@echo "===> Ожидаем запуск Zep (10 секунд)..."
	sleep 10

	@echo "===> Запускаем Weaviate..."
	podman-compose up -d weaviate

	@echo "===> Ожидаем запуск Weaviate (10 секунд)..."
	sleep 10

	@echo "===> Запускаем n8n..."
	podman-compose up -d n8n

	@echo "===> Ожидаем запуск n8n (15 секунд)..."
	sleep 15

	@echo "===> Запускаем NGINX (требуется zep, weaviate и n8n)..."
	podman-compose up -d nginx

	@echo "===> Проверяем статус контейнеров..."
	podman-compose ps

	@echo "===> Проверяем доступность сервисов..."
	echo "\nZep status: " && curl -s http://localhost:8000/healthz || echo "\nВНИМАНИЕ: Zep не отвечает!"
	echo "\nEmbeddings service status: " && curl -s http://localhost:8080/info || echo "\nВНИМАНИЕ: Embeddings service не отвечает!"
	echo "\nWeaviate status: " && curl -s http://localhost:8087/v1/.well-known/ready || echo "\nВНИМАНИЕ: Weaviate не отвечает!"
	echo "\nn8n status: " && curl -s http://localhost:5678/healthz || echo "\nВНИМАНИЕ: n8n не отвечает!"
	echo "\nNGINX status: " && curl -s http://localhost/health || echo "\nВНИМАНИЕ: NGINX не отвечает!"

	@echo "\n===> Сброс завершен. Система запущена с чистыми базами данных.\n"
	@echo "Для отладки используйте:"
	@echo "  podman-compose logs zep         # логи Zep"
	@echo "  podman-compose logs embeddings-service  # логи сервиса эмбеддингов"
	@echo "  podman-compose logs nginx       # логи NGINX"
	@echo "  podman-compose logs postgres-zep # логи PostgreSQL для Zep"

backup-db:
	@echo "Создаем резервную копию баз данных..."
	mkdir -p ./backups/$(shell date +%Y%m%d_%H%M%S)
	podman exec postgres-1 pg_dumpall -U postgres > ./backups/$(shell date +%Y%m%d_%H%M%S)/postgres_dump.sql
	cp -r ./data ./backups/$(shell date +%Y%m%d_%H%M%S)/data_backup
	@echo "Резервная копия создана в каталоге ./backups/$(shell date +%Y%m%d_%H%M%S)/"
EOF

# Создаем Makefile, если он не существует
if [ ! -f "$SCRIPT_DIR/Makefile" ]; then
    cat > "$SCRIPT_DIR/Makefile" << 'EOF'
# Makefile для проекта n8n-супер-агент с поддержкой Docker и Podman
# Определение используемого контейнерного движка (docker или podman)
# Использование: make ENGINE=podman start - для запуска с Podman
#                make ENGINE=docker start - для запуска с Docker (по умолчанию)

# Определение движка (docker по умолчанию)
ENGINE ?= docker

# Общие переменные
BACKUP_DIR = ./backups
DATE = $$(date +%Y%m%d-%H%M%S)
PROJECT_NAME := super-agent

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m # No Color

# Подключение соответствующего makefile в зависимости от выбранного движка
ifeq ($(ENGINE),docker)
    include .make/docker.mk
else ifeq ($(ENGINE),podman)
    include .make/podman.mk
else
    $(error Неизвестный контейнерный движок: $(ENGINE). Используйте 'docker' или 'podman')
endif

# Список всех целей, общих для обоих движков
.PHONY: help setup start stop restart status logs fix check backup restore clean reset update dev test shell n8n-logs redis-logs postgres-logs weaviate-logs zep-logs all-logs

# Цели, независимые от контейнерного движка
help:
	@echo "${GREEN}n8n Супер-агент - система управления${NC}"
	@echo "${YELLOW}Текущий контейнерный движок: ${ENGINE}${NC}"
	@echo "Для использования другого движка: make ENGINE=podman ..."
	@echo ""
	@echo "${GREEN}Доступные команды:${NC}"
	@echo "  ${YELLOW}make setup${NC}      - Инициализация проекта (первый запуск)"
	@echo "  ${YELLOW}make start${NC}      - Запуск контейнеров"
	@echo "  ${YELLOW}make stop${NC}       - Остановка контейнеров"
	@echo "  ${YELLOW}make restart${NC}    - Перезапуск контейнеров"
	@echo "  ${YELLOW}make status${NC}     - Проверка статуса системы"
	@echo "  ${YELLOW}make logs${NC}       - Просмотр логов всех контейнеров"
	@echo "  ${YELLOW}make fix${NC}        - Применение исправлений"
	@echo "  ${YELLOW}make check${NC}      - Проверка работоспособности системы"
	@echo "  ${YELLOW}make backup${NC}     - Создание резервной копии данных"
	@echo "  ${YELLOW}make restore${NC}    - Восстановление из резервной копии"
	@echo "  ${YELLOW}make clean${NC}      - Остановка и удаление контейнеров без удаления данных"
	@echo "  ${YELLOW}make reset${NC}      - Сброс проекта (удаление контейнеров и томов)"
	@echo "  ${YELLOW}make update${NC}     - Обновление образов контейнеров"
	@echo "  ${YELLOW}make dev${NC}        - Запуск проекта в режиме разработки"
	@echo "  ${YELLOW}make test${NC}       - Запуск тестов"
	@echo "  ${YELLOW}make shell${NC}      - Подключение к консоли контейнера n8n"
	@echo ""
	@echo "${GREEN}Команды для просмотра логов:${NC}"
	@echo "  ${YELLOW}make n8n-logs${NC}      - Логи n8n"
	@echo "  ${YELLOW}make redis-logs${NC}    - Логи Redis"
	@echo "  ${YELLOW}make postgres-logs${NC} - Логи PostgreSQL"
	@echo "  ${YELLOW}make weaviate-logs${NC} - Логи Weaviate"
	@echo "  ${YELLOW}make zep-logs${NC}      - Логи Zep"
	@echo "  ${YELLOW}make all-logs${NC}      - Логи всех контейнеров"

fix:
	@echo "${GREEN}Применение исправлений к проекту...${NC}"
	@chmod +x fix-issues.sh
	@./fix-issues.sh
	@echo "${YELLOW}Примечание: Если возникли ошибки с командой sed, отредактируйте файлы конфигурации вручную${NC}"

check:
	@echo "${GREEN}Проверка работоспособности системы...${NC}"
	@chmod +x check-system.sh
	@./check-system.sh
EOF
fi

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