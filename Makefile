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