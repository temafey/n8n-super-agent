# Makefile для Ansible проекта n8n-super-agent

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[0;33m
NC = \033[0m # No Color

# Переменные
INVENTORY = inventory.ini
PLAYBOOK = n8n-super-agent.yml
ROLES_PLAYBOOK = n8n-super-agent-roles.yml
VAULT_FILE = group_vars/n8n_servers/vault.yml
VAULT_PASSWORD_FILE = .vault_password
SETUP_ARGS ?= --skip-certs

.PHONY: help setup lint syntax-check check dry-run apply roles vault encrypt decrypt edit-vault tags clean install requirements

# Помощь
help:
	@echo "$(GREEN)Ansible для n8n-super-agent$(NC)"
	@echo ""
	@echo "$(YELLOW)Доступные команды:$(NC)"
	@echo "  $(GREEN)make setup$(NC)           - Установка зависимостей Ansible и подготовка окружения"
	@echo "  $(GREEN)make requirements$(NC)    - Установка необходимых ролей и коллекций Ansible"
	@echo "  $(GREEN)make lint$(NC)            - Проверка правил оформления и синтаксиса ansible-lint"
	@echo "  $(GREEN)make syntax-check$(NC)    - Проверка синтаксиса playbook"
	@echo "  $(GREEN)make check$(NC)           - Проверка синтаксиса и правил оформления"
	@echo "  $(GREEN)make dry-run$(NC)         - Запуск в режиме симуляции (без изменений)"
	@echo "  $(GREEN)make apply$(NC)           - Применение playbook"
	@echo "  $(GREEN)make roles$(NC)           - Применение playbook с ролями"
	@echo ""
	@echo "$(YELLOW)Шифрование:$(NC)"
	@echo "  $(GREEN)make encrypt$(NC)         - Шифрование $(VAULT_FILE)"
	@echo "  $(GREEN)make decrypt$(NC)         - Расшифровка $(VAULT_FILE)"
	@echo "  $(GREEN)make edit-vault$(NC)      - Редактирование зашифрованного $(VAULT_FILE)"
	@echo "  $(GREEN)make vault FILE=path$(NC) - Шифрование указанного файла"
	@echo ""
	@echo "$(YELLOW)Запуск с тегами:$(NC)"
	@echo "  $(GREEN)make tags TAGS=tag1,tag2$(NC) - Запуск только указанных тегов"
	@echo ""
	@echo "$(YELLOW)Очистка:$(NC)"
	@echo "  $(GREEN)make clean$(NC)           - Удаление временных файлов"
	@echo ""
	@echo "Используйте INVENTORY=path/to/inventory для указания другого инвентаря"
	@echo "Используйте ASK_PASS=--ask-become-pass для запроса sudo пароля"
	@echo "Используйте TARGET=host1,host2 для ограничения хостов"
	@echo "Используйте SETUP_ARGS=\"\" для генерации сертификатов (по умолчанию: --skip-certs)"

# Установка зависимостей и подготовка окружения
setup: requirements
	@echo "$(GREEN)Подготовка окружения Ansible...$(NC)"
	@if [ ! -f $(VAULT_PASSWORD_FILE) ]; then \
		echo "$(YELLOW)Создание файла с паролем для vault...$(NC)"; \
		read -s -p "Введите пароль для vault: " VAULT_PASS && echo "" && \
		echo "$$VAULT_PASS" > $(VAULT_PASSWORD_FILE) && \
		chmod 600 $(VAULT_PASSWORD_FILE) && \
		echo "$(GREEN)Файл $(VAULT_PASSWORD_FILE) создан.$(NC)"; \
	else \
		echo "$(YELLOW)Файл $(VAULT_PASSWORD_FILE) уже существует.$(NC)"; \
	fi
	@if [ ! -f $(VAULT_FILE) ]; then \
		echo "$(YELLOW)Создание шаблона vault-файла...$(NC)"; \
		cp -n group_vars/n8n_servers/vault.yml.example $(VAULT_FILE) 2>/dev/null || \
		echo "vault_n8n_password: 'changeme'\nvault_n8n_encryption_key: 'changeme'\nvault_redis_password: 'changeme'\nvault_openai_api_key: 'changeme'" > $(VAULT_FILE); \
		echo "$(GREEN)Файл $(VAULT_FILE) создан. Отредактируйте его и зашифруйте с помощью 'make encrypt'.$(NC)"; \
	else \
		echo "$(YELLOW)Файл $(VAULT_FILE) уже существует.$(NC)"; \
	fi
	@echo "$(GREEN)Окружение подготовлено. Теперь вы можете редактировать переменные и запускать playbook.$(NC)"

# Установка требуемых ролей и коллекций
requirements:
	@echo "$(GREEN)Установка необходимых ролей и коллекций Ansible...$(NC)"
	@ansible-galaxy collection install community.general >/dev/null || echo "$(RED)Ошибка установки community.general$(NC)"
	@ansible-galaxy collection install ansible.posix >/dev/null || echo "$(RED)Ошибка установки ansible.posix$(NC)"
	@echo "$(GREEN)Все зависимости установлены.$(NC)"

# Проверка правил оформления
lint:
	@echo "$(GREEN)Проверка правил оформления и синтаксиса с ansible-lint...$(NC)"
	@if command -v ansible-lint >/dev/null 2>&1; then \
		ansible-lint *.yml || echo "$(RED)Найдены проблемы с оформлением.$(NC)"; \
	else \
		echo "$(RED)ansible-lint не установлен. Установите его с помощью 'pip install ansible-lint'.$(NC)"; \
	fi

# Проверка синтаксиса
syntax-check:
	@echo "$(GREEN)Проверка синтаксиса playbook...$(NC)"
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --syntax-check
	@ansible-playbook -i $(INVENTORY) $(ROLES_PLAYBOOK) --syntax-check

# Комбинированная проверка
check: syntax-check lint
	@echo "$(GREEN)Проверка завершена.$(NC)"

# Запуск в режиме dry-run
dry-run:
	@echo "$(GREEN)Запуск в режиме symulated run (без изменений)...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check --diff --vault-password-file $(VAULT_PASSWORD_FILE) $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	else \
		ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check --diff --ask-vault-pass $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	fi

# Применение playbook
apply:
	@echo "$(GREEN)Применение playbook...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --vault-password-file $(VAULT_PASSWORD_FILE) $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	else \
		ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --ask-vault-pass $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	fi

# Применение playbook с ролями
roles:
	@echo "$(GREEN)Применение playbook с ролями...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-playbook -i $(INVENTORY) $(ROLES_PLAYBOOK) --vault-password-file $(VAULT_PASSWORD_FILE) $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	else \
		ansible-playbook -i $(INVENTORY) $(ROLES_PLAYBOOK) --ask-vault-pass $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
	fi

# Шифрование vault-файла
encrypt:
	@echo "$(GREEN)Шифрование $(VAULT_FILE)...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-vault encrypt $(if $(FILE),$(FILE),$(VAULT_FILE)) --vault-password-file $(VAULT_PASSWORD_FILE); \
	else \
		ansible-vault encrypt $(if $(FILE),$(FILE),$(VAULT_FILE)); \
	fi
	@echo "$(GREEN)Файл зашифрован.$(NC)"

# Расшифровка vault-файла
decrypt:
	@echo "$(GREEN)Расшифровка $(VAULT_FILE)...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-vault decrypt $(if $(FILE),$(FILE),$(VAULT_FILE)) --vault-password-file $(VAULT_PASSWORD_FILE); \
	else \
		ansible-vault decrypt $(if $(FILE),$(FILE),$(VAULT_FILE)); \
	fi
	@echo "$(GREEN)Файл расшифрован. Не забудьте зашифровать его снова после редактирования.$(NC)"

# Редактирование зашифрованного vault-файла
edit-vault:
	@echo "$(GREEN)Редактирование зашифрованного $(VAULT_FILE)...$(NC)"
	@if [ -f $(VAULT_PASSWORD_FILE) ]; then \
		ansible-vault edit $(VAULT_FILE) --vault-password-file $(VAULT_PASSWORD_FILE); \
	else \
		ansible-vault edit $(VAULT_FILE); \
	fi

# Запуск с определенными тегами
tags:
	@if [ -z "$(TAGS)" ]; then \
		echo "$(RED)Не указаны теги. Используйте 'make tags TAGS=tag1,tag2'.$(NC)"; \
	else \
		echo "$(GREEN)Запуск playbook с тегами: $(TAGS)...$(NC)"; \
		if [ -f $(VAULT_PASSWORD_FILE) ]; then \
			ansible-playbook -i $(INVENTORY) $(ROLES_PLAYBOOK) --vault-password-file $(VAULT_PASSWORD_FILE) --tags "$(TAGS)" $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
		else \
			ansible-playbook -i $(INVENTORY) $(ROLES_PLAYBOOK) --ask-vault-pass --tags "$(TAGS)" $(ASK_PASS) $(if $(TARGET),--limit $(TARGET),); \
		fi; \
	fi

# Очистка временных файлов
clean:
	@echo "$(GREEN)Удаление временных файлов...$(NC)"
	@find . -name "*.retry" -type f -delete
	@find . -name "*.pyc" -type f -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} +
	@echo "$(GREEN)Очистка завершена.$(NC)"

# Создание шаблона vault.yml.example
install:
	@echo "$(GREEN)Создание шаблона vault.yml.example...$(NC)"
	@if [ ! -f "group_vars/n8n_servers/vault.yml.example" ]; then \
		echo "# Пример файла с секретными переменными - скопируйте в vault.yml и зашифруйте\n\n\
vault_n8n_password: 'admin_password'\n\
vault_n8n_encryption_key: 'your-long-random-encryption-key'\n\
vault_redis_password: 'redis_secure_password'\n\
vault_openai_api_key: 'your-openai-api-key'" > group_vars/n8n_servers/vault.yml.example; \
		echo "$(GREEN)Шаблон vault.yml.example создан.$(NC)"; \
	else \
		echo "$(YELLOW)Файл vault.yml.example уже существует.$(NC)"; \
	fi
