# Роли Ansible для n8n-super-agent

Здесь описаны роли, используемые для установки и настройки проекта n8n-super-agent.

## Доступные роли

### docker

Устанавливает и настраивает Docker и Docker Compose.

**Тэги:** `docker`

**Задачи:**
- Установка Docker Engine
- Установка Docker Compose
- Настройка пользователя для работы с Docker без sudo
- Настройка служб Docker

### security

Настраивает основные аспекты безопасности сервера.

**Тэги:** `security`

**Задачи:**
- Настройка fail2ban для защиты от брутфорс-атак
- Настройка брандмауэра ufw
- Настройка безопасных параметров SSH
- Настройка автоматических обновлений безопасности

### n8n-setup

Устанавливает и настраивает n8n-super-agent.

**Тэги:** `n8n-setup`

**Задачи:**
- Клонирование репозитория проекта
- Создание необходимых директорий
- Настройка переменных окружения
- Создание SSL-сертификатов
- Запуск и настройка сервиса
- Настройка заданий cron для обслуживания

## Использование ролей

### В вашем playbook

```yaml
- hosts: n8n_servers
  become: yes
  roles:
    - role: docker
    - role: security
    - role: n8n-setup
```

### С тегами

Для запуска только определенных ролей, используйте теги:

```bash
ansible-playbook -i inventory.ini n8n-super-agent-roles.yml --tags "docker,security"
```

### Параметры ролей

Основные параметры настраиваются в файле `group_vars/n8n_servers/vars.yml`. Вы можете переопределить их при вызове роли:

```yaml
- hosts: n8n_servers
  become: yes
  roles:
    - role: n8n-setup
      vars:
        project_dir: /srv/n8n-super-agent
        enable_backups: false
```