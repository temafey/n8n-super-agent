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
  include .make/docker.mk
else ifeq ($(ENGINE),podman)
  include .make/podman.mk
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
