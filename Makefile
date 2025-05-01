# Оптимизированный Makefile для проекта n8n-супер-агент
# Поддерживает Docker и Podman контейнеры
# Использование: make ENGINE=podman команда (по умолчанию используется docker)

# Определение движка (docker по умолчанию)
ENGINE ?= docker

# Общие переменные
BACKUP_DIR = ./backups
DATE = $(shell date +%Y%m%d-%H%M%S)
PROJECT_NAME = n8n-super-agent
LOGS_DIR = ./logs

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m # No Color

# Настройка команд в зависимости от выбранного движка
ifeq ($(ENGINE),docker)
  CONTAINER_CMD = docker
  COMPOSE_CMD = docker-compose
  COMPOSE_FILE = docker-compose.yml
  CONTAINER_PREFIX = $(PROJECT_NAME)_
else ifeq ($(ENGINE),podman)
  CONTAINER_CMD = podman
  COMPOSE_CMD = podman-compose
  COMPOSE_FILE = podman-compose.yml
  CONTAINER_PREFIX = $(PROJECT_NAME)_
else
  $(error Неизвестный движок: $(ENGINE). Используйте 'docker' или 'podman')
endif

# Динамическое определение ID контейнеров
N8N_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)n8n")
POSTGRES_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)postgres")
WEAVIATE_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)weaviate")
ZEP_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)zep")
REDIS_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)redis")
NGINX_CONTAINER = $(shell $(CONTAINER_CMD) ps -qf "name=$(CONTAINER_PREFIX)nginx")

# Список всех целей
.PHONY: help setup start stop restart status stats logs fix check backup restore clean reset update dev test shell \
        n8n-logs redis-logs postgres-logs weaviate-logs zep-logs nginx-logs all-logs reset-db backup-db

# Справка по командам
help:
	@echo "$(GREEN)n8n Супер-агент - система управления$(NC)"
	@echo "$(YELLOW)Текущий контейнерный движок: $(ENGINE)$(NC)"
	@echo "Для использования другого движка: make ENGINE=podman ..."
	@echo ""
	@echo "$(GREEN)Основные команды:$(NC)"
	@echo "  $(YELLOW)make setup$(NC)      - Инициализация проекта (первый запуск)"
	@echo "  $(YELLOW)make start$(NC)      - Запуск контейнеров"
	@echo "  $(YELLOW)make stop$(NC)       - Остановка контейнеров"
	@echo "  $(YELLOW)make restart$(NC)    - Перезапуск контейнеров"
	@echo "  $(YELLOW)make status$(NC)     - Проверка статуса системы"
	@echo "  $(YELLOW)make stats$(NC)      - Статистика контейнеров (CPU, память)"
	@echo "  $(YELLOW)make logs$(NC)       - Просмотр логов всех контейнеров"
	@echo ""
	@echo "$(GREEN)Обслуживание:$(NC)"
	@echo "  $(YELLOW)make fix$(NC)        - Применение исправлений"
	@echo "  $(YELLOW)make check$(NC)      - Проверка работоспособности системы"
	@echo "  $(YELLOW)make backup$(NC)     - Создание резервной копии данных"
	@echo "  $(YELLOW)make restore$(NC)    - Восстановление из резервной копии"
	@echo "  $(YELLOW)make clean$(NC)      - Удаление контейнеров без удаления данных"
	@echo "  $(YELLOW)make reset$(NC)      - Сброс проекта (удаление контейнеров и томов)"
	@echo "  $(YELLOW)make update$(NC)     - Обновление образов контейнеров"
	@echo "  $(YELLOW)make reset-db$(NC)   - Сброс и переинициализация баз данных"
	@echo "  $(YELLOW)make backup-db$(NC)  - Быстрое резервное копирование БД"
	@echo ""
	@echo "$(GREEN)Разработка:$(NC)"
	@echo "  $(YELLOW)make dev$(NC)        - Запуск в режиме разработки"
	@echo "  $(YELLOW)make test$(NC)       - Запуск тестов"
	@echo "  $(YELLOW)make shell$(NC)      - Подключение к консоли контейнера n8n"
	@echo ""
	@echo "$(GREEN)Логи отдельных сервисов:$(NC)"
	@echo "  $(YELLOW)make n8n-logs$(NC)       - Логи n8n"
	@echo "  $(YELLOW)make redis-logs$(NC)     - Логи Redis"
	@echo "  $(YELLOW)make postgres-logs$(NC)  - Логи PostgreSQL"
	@echo "  $(YELLOW)make weaviate-logs$(NC)  - Логи Weaviate"
	@echo "  $(YELLOW)make zep-logs$(NC)       - Логи Zep"
	@echo "  $(YELLOW)make nginx-logs$(NC)     - Логи NGINX"

# Инициализация проекта
setup:
	@echo "$(GREEN)Инициализация проекта n8n-супер-агент с $(ENGINE)...$(NC)"
	@chmod +x *.sh
	@./setup.sh $(if $(filter podman,$(ENGINE)),-e podman,)

# Управление сервисами
start:
	@echo "$(GREEN)Запуск контейнеров с $(ENGINE)...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Контейнеры запущены. n8n доступен по адресу: https://localhost$(NC)"

stop:
	@echo "$(GREEN)Остановка контейнеров...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) stop
	@echo "$(GREEN)Контейнеры остановлены$(NC)"

restart:
	@echo "$(GREEN)Перезапуск контейнеров...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) restart
	@echo "$(GREEN)Контейнеры перезапущены$(NC)"

status:
	@echo "$(GREEN)Статус контейнеров ($(ENGINE)):$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) ps

stats:
	@echo "$(GREEN)Статистика контейнеров ($(ENGINE)):$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) stats

# Работа с логами
logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f

n8n-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f n8n

redis-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f redis

postgres-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f postgres

weaviate-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f weaviate

zep-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f zep

nginx-logs:
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs --tail=100 -f nginx

# Обслуживание
fix:
	@echo "$(GREEN)Применение исправлений к проекту...$(NC)"
	@if [ -f fix-issues.sh ]; then \
		chmod +x fix-issues.sh; \
		./fix-issues.sh; \
	else \
		echo "$(RED)Скрипт fix-issues.sh не найден$(NC)"; \
	fi

check:
	@echo "$(GREEN)Проверка работоспособности системы...$(NC)"
	@if [ -f check-system.sh ]; then \
		chmod +x check-system.sh; \
		./check-system.sh; \
	else \
		echo "$(YELLOW)Проверяем доступность основных сервисов:$(NC)"; \
		echo -n "n8n: "; curl -s http://localhost:5678/healthz > /dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"; \
		echo -n "Weaviate: "; curl -s http://localhost:8087/v1/.well-known/ready > /dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"; \
		echo -n "Zep: "; curl -s http://localhost:8000/healthz > /dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"; \
		echo -n "NGINX: "; curl -s http://localhost/health > /dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"; \
	fi

# Резервное копирование и восстановление
backup:
	@echo "$(GREEN)Создание резервной копии данных ($(ENGINE))...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@echo "Создание дампа PostgreSQL..."
	@if [ ! -z "$(POSTGRES_CONTAINER)" ]; then \
		$(CONTAINER_CMD) exec $(POSTGRES_CONTAINER) pg_dump -U n8n -d n8n > $(BACKUP_DIR)/n8n-db-$(DATE).sql; \
		echo "БД сохранена в $(BACKUP_DIR)/n8n-db-$(DATE).sql"; \
	else \
		echo "$(RED)Контейнер PostgreSQL не найден или не запущен$(NC)"; \
	fi
	@echo "Создание резервной копии workflows..."
	@tar -czvf $(BACKUP_DIR)/workflows-$(DATE).tar.gz workflows
	@echo "Создание резервной копии настроек..."
	@tar -czvf $(BACKUP_DIR)/config-$(DATE).tar.gz .env $(COMPOSE_FILE) nginx
	@echo "$(GREEN)Резервная копия создана в директории $(BACKUP_DIR)$(NC)"

restore:
	@echo "$(RED)Восстановление данных из резервной копии ($(ENGINE))...$(NC)"
	@echo "$(YELLOW)Предупреждение: Эта операция перезапишет текущие данные!$(NC)"
	@echo "Доступные резервные копии БД:"
	@find $(BACKUP_DIR) -name "n8n-db-*.sql" -type f | sed 's|.*/n8n-db-||g' | sed 's|\.sql||g' | sort
	@echo "Доступные резервные копии workflows:"
	@find $(BACKUP_DIR) -name "workflows-*.tar.gz" -type f | sed 's|.*/workflows-||g' | sed 's|\.tar\.gz||g' | sort
	@read -p "Введите дату резервной копии (например, $(shell date +%Y%m%d-%H%M%S)): " date; \
	if [ -f "$(BACKUP_DIR)/n8n-db-$$date.sql" ] && [ -f "$(BACKUP_DIR)/workflows-$$date.tar.gz" ]; then \
		echo "Восстановление БД из $(BACKUP_DIR)/n8n-db-$$date.sql..."; \
		if [ ! -z "$(POSTGRES_CONTAINER)" ]; then \
			$(CONTAINER_CMD) exec -i $(POSTGRES_CONTAINER) psql -U n8n -d n8n < $(BACKUP_DIR)/n8n-db-$$date.sql; \
			echo "Восстановление workflows из $(BACKUP_DIR)/workflows-$$date.tar.gz..."; \
			tar -xzvf $(BACKUP_DIR)/workflows-$$date.tar.gz; \
			echo "$(GREEN)Восстановление завершено$(NC)"; \
		else \
			echo "$(RED)Контейнер PostgreSQL не найден или не запущен$(NC)"; \
		fi \
	else \
		echo "$(RED)Резервная копия с датой $$date не найдена$(NC)"; \
	fi

# Очистка и сброс
clean:
	@echo "$(YELLOW)Остановка и удаление контейнеров (без удаления данных)...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Контейнеры удалены. Данные сохранены в томах.$(NC)"

reset:
	@echo "$(RED)Сброс проекта ($(ENGINE))...$(NC)"
	@echo "$(YELLOW)Предупреждение: Эта операция удалит ВСЕ данные проекта!$(NC)"
	@read -p "Продолжить? (введите 'reset' для подтверждения): " confirm; \
	if [ "$$confirm" = "reset" ]; then \
		echo "Удаление контейнеров и томов..."; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) down -v; \
		echo "$(GREEN)Сброс завершен. Все данные удалены.$(NC)"; \
	else \
		echo "$(RED)Сброс отменен$(NC)"; \
	fi

# Обновление и разработка
update:
	@echo "$(GREEN)Обновление образов контейнеров ($(ENGINE))...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) pull
	@echo "$(GREEN)Образы обновлены. Перезапустите контейнеры: make restart$(NC)"

dev:
	@echo "$(GREEN)Запуск в режиме разработки ($(ENGINE))...$(NC)"
	@$(COMPOSE_CMD) -f $(COMPOSE_FILE) up

test:
	@echo "$(GREEN)Запуск тестов...$(NC)"
	@echo "Проверка доступности сервисов..."
	@$(MAKE) check
	@if [ -d examples ]; then \
		echo "Тестирование примеров API..."; \
		if [ -f examples/api-usage.js ]; then \
			echo "Запуск api-usage.js..."; \
			node examples/api-usage.js || echo "$(RED)Тест api-usage.js завершился с ошибкой$(NC)"; \
		fi; \
		if [ -f examples/weaviate-test.js ]; then \
			echo "Запуск weaviate-test.js..."; \
			node examples/weaviate-test.js || echo "$(RED)Тест weaviate-test.js завершился с ошибкой$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)Директория examples не найдена, тесты пропущены$(NC)"; \
	fi

shell:
	@echo "$(GREEN)Подключение к контейнеру n8n ($(ENGINE))...$(NC)"
	@if [ ! -z "$(N8N_CONTAINER)" ]; then \
		$(CONTAINER_CMD) exec -it $(N8N_CONTAINER) /bin/sh; \
	else \
		echo "$(RED)Контейнер n8n не найден или не запущен$(NC)"; \
	fi

# Полный сброс данных и перезапуск системы
reset-db:
	@echo "$(GREEN)Сброс и переинициализация баз данных...$(NC)"
	@read -p "Эта операция удалит все данные из баз. Продолжить? (y/n): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		echo "Останавливаем все контейнеры..."; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) down; \
		echo "Удаляем тома с данными..."; \
		for vol in n8n_data postgres_data postgres_zep_data zep_data redis_data weaviate_data; do \
			$(CONTAINER_CMD) volume rm $$vol 2>/dev/null || true; \
		done; \
		echo "Очищаем каталоги с логами..."; \
		for dir in n8n postgres postgres-zep zep redis weaviate nginx; do \
			rm -rf $(LOGS_DIR)/$$dir/* 2>/dev/null || true; \
			mkdir -p $(LOGS_DIR)/$$dir; \
		done; \
		echo "Запускаем базы данных в первую очередь..."; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d postgres postgres-zep; \
		echo "Ожидаем инициализации баз данных (15 секунд)..."; \
		sleep 15; \
		echo "Запускаем остальные сервисы..."; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d redis embeddings-service; \
		sleep 10; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d zep weaviate; \
		sleep 10; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d n8n; \
		sleep 15; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d nginx; \
		echo "Проверяем статус контейнеров..."; \
		$(COMPOSE_CMD) -f $(COMPOSE_FILE) ps; \
		echo "$(GREEN)Сброс завершен. Система запущена с чистыми базами данных.$(NC)"; \
	else \
		echo "$(RED)Операция отменена$(NC)"; \
	fi

backup-db:
	@echo "$(GREEN)Создаем резервную копию баз данных...$(NC)"
	@BACKUP_SUBDIR=$(BACKUP_DIR)/$(shell date +%Y%m%d_%H%M%S); \
	mkdir -p $$BACKUP_SUBDIR; \
	if [ ! -z "$(POSTGRES_CONTAINER)" ]; then \
		echo "Создание дампа PostgreSQL..."; \
		$(CONTAINER_CMD) exec $(POSTGRES_CONTAINER) pg_dump -U n8n -d n8n > $$BACKUP_SUBDIR/postgres_dump.sql; \
		echo "Резервная копия создана в каталоге $$BACKUP_SUBDIR/"; \
	else \
		echo "$(RED)Контейнер PostgreSQL не найден или не запущен$(NC)"; \
	fi