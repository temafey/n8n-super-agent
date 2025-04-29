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