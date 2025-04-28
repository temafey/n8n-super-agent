# Makefile для проекта n8n-супер-агент
# Содержит основные команды для управления проектом

# Переменные
DOCKER_COMPOSE = docker-compose
N8N_CONTAINER = $$(docker ps -qf "name=n8n-super-agent_n8n")
POSTGRES_CONTAINER = $$(docker ps -qf "name=n8n-super-agent_postgres")
BACKUP_DIR = ./backups
DATE = $$(date +%Y%m%d-%H%M%S)
# Имя проекта (используется для идентификации томов Docker)
PROJECT_NAME := super-agent

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m # No Color

.PHONY: help setup start stop restart status logs fix check backup restore clean reset update dev test shell n8n-logs redis-logs postgres-logs weaviate-logs zep-logs all-logs

# Вывод доступных команд
help:
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

# Инициализация проекта
setup:
	@echo "${GREEN}Инициализация проекта n8n-супер-агент...${NC}"
	@chmod +x *.sh
	@./setup.sh

# Запуск контейнеров
start:
	@echo "${GREEN}Запуск контейнеров...${NC}"
	@$(DOCKER_COMPOSE) up -d
	@echo "${GREEN}Контейнеры запущены. n8n доступен по адресу: https://localhost${NC}"

# Остановка контейнеров
stop:
	@echo "${GREEN}Остановка контейнеров...${NC}"
	@$(DOCKER_COMPOSE) stop
	@echo "${GREEN}Контейнеры остановлены${NC}"

# Перезапуск контейнеров
restart:
	@echo "${GREEN}Перезапуск контейнеров...${NC}"
	@$(DOCKER_COMPOSE) restart
	@echo "${GREEN}Контейнеры перезапущены${NC}"

# Проверка статуса системы
status:
	@echo "${GREEN}Статус контейнеров:${NC}"
	@$(DOCKER_COMPOSE) ps

# Проверка статуса системы
stats:
	@echo "${GREEN}Статистика контейнеров:${NC}"
	@$(DOCKER_COMPOSE) stats

# Просмотр логов всех контейнеров
logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f

# Применение исправлений
fix:
	@echo "${GREEN}Применение исправлений к проекту...${NC}"
	@chmod +x fix-issues.sh
	@./fix-issues.sh
	@echo "${YELLOW}Примечание: Если возникли ошибки с командой sed, отредактируйте docker-compose.yml вручную, чтобы добавить монтирование директории lib/${NC}"

# Проверка работоспособности системы
check:
	@echo "${GREEN}Проверка работоспособности системы...${NC}"
	@chmod +x check-system.sh
	@./check-system.sh

# Создание резервной копии данных
backup:
	@echo "${GREEN}Создание резервной копии данных...${NC}"
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
	@echo "${RED}Восстановление данных из резервной копии...${NC}"
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
	@$(DOCKER_COMPOSE) down
	@echo "${GREEN}Контейнеры удалены. Данные сохранены в томах Docker.${NC}"

# Полный сброс проекта
reset:
	@echo "${RED}Сброс проекта...${NC}"
	@echo "${YELLOW}Предупреждение: Эта операция удалит ВСЕ данные проекта!${NC}"
	@read -p "Продолжить? (введите 'reset' для подтверждения): " confirm; \
	if [ "$$confirm" = "reset" ]; then \
		echo "Удаление контейнеров и томов..."; \
		$(DOCKER_COMPOSE) down -v; \
		echo "${GREEN}Сброс завершен. Все данные удалены.${NC}"; \
	else \
		echo "${RED}Сброс отменен${NC}"; \
	fi

# Обновление образов
update:
	@echo "${GREEN}Обновление образов контейнеров...${NC}"
	@$(DOCKER_COMPOSE) pull
	@echo "${GREEN}Образы обновлены. Перезапустите контейнеры: make restart${NC}"

# Запуск в режиме разработки
dev:
	@echo "${GREEN}Запуск в режиме разработки...${NC}"
	@$(DOCKER_COMPOSE) up

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
	@echo "${GREEN}Подключение к контейнеру n8n...${NC}"
	@docker exec -it $(N8N_CONTAINER) /bin/sh

# Команды для просмотра логов отдельных сервисов
n8n-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f n8n

redis-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f redis

postgres-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f postgres

weaviate-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f weaviate

zep-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f zep

all-logs:
	@$(DOCKER_COMPOSE) logs --tail=100 -f


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