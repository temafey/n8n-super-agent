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

# Сборка образов
build:
	@echo "${GREEN}Сборка образов контейнеров с Podman...${NC}"
	@$(COMPOSE_CMD) build
	@echo "${GREEN}Образы собраны. Используйте 'make start' для запуска контейнеров.${NC}"

# Сборка и запуск
up:
	@echo "${GREEN}Сборка и запуск контейнеров с Podman...${NC}"
	@$(COMPOSE_CMD) up -d --build
	@echo "${GREEN}Контейнеры собраны и запущены. n8n доступен по адресу: https://localhost${NC}"

# Пересборка конкретного сервиса
rebuild-service:
	@read -p "Введите имя сервиса для пересборки: " service; \
	echo "${GREEN}Пересборка сервиса $$service с Podman...${NC}"; \
	$(COMPOSE_CMD) build --no-cache $$service; \
	echo "${GREEN}Сервис $$service пересобран. Выполните 'make ENGINE=podman restart' для применения изменений.${NC}"

# Обновление зависимостей и пересборка всех образов
rebuild-all:
	@echo "${GREEN}Полная пересборка всех образов с Podman (с отключенным кешем)...${NC}"
	@$(COMPOSE_CMD) build --no-cache
	@echo "${GREEN}Все образы пересобраны. Выполните 'make ENGINE=podman restart' для применения изменений.${NC}"

# Обновление базовых образов и пересборка
pull-build:
	@echo "${GREEN}Обновление базовых образов и пересборка с Podman...${NC}"
	@$(COMPOSE_CMD) pull
	@$(COMPOSE_CMD) build
	@echo "${GREEN}Образы обновлены и пересобраны. Выполните 'make ENGINE=podman restart' для применения изменений.${NC}"

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
