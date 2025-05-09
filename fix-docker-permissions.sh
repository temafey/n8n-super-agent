#!/bin/bash

# Цвета для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Проверка запуска от root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Этот скрипт должен быть запущен с правами root (sudo)${NC}"
  echo -e "Запустите: ${YELLOW}sudo $0${NC}"
  exit 1
fi

echo -e "${GREEN}Исправление прав доступа к Docker...${NC}"

# Текущий пользователь
CURRENT_USER=$(logname || echo "$SUDO_USER")
if [ -z "$CURRENT_USER" ]; then
  CURRENT_USER=$(who am i | awk '{print $1}')
fi

echo -e "${YELLOW}Текущий пользователь: $CURRENT_USER${NC}"

# Проверяем, существует ли группа docker
if ! getent group docker > /dev/null; then
  echo -e "${YELLOW}Группа docker не существует, создаем...${NC}"
  groupadd docker
  echo -e "${GREEN}Группа docker создана${NC}"
fi

# Добавляем пользователя в группу docker
if ! groups "$CURRENT_USER" | grep -q docker; then
  echo -e "${YELLOW}Добавляем пользователя $CURRENT_USER в группу docker...${NC}"
  usermod -aG docker "$CURRENT_USER"
  echo -e "${GREEN}Пользователь $CURRENT_USER добавлен в группу docker${NC}"
else
  echo -e "${GREEN}Пользователь $CURRENT_USER уже в группе docker${NC}"
fi

# Устанавливаем правильные разрешения на docker.sock
echo -e "${YELLOW}Устанавливаем правильные разрешения на /var/run/docker.sock...${NC}"
chmod 666 /var/run/docker.sock
echo -e "${GREEN}Разрешения на /var/run/docker.sock обновлены${NC}"

# Создаем systemd override для сохранения разрешений при перезапуске
if [ -d /etc/systemd/system ]; then
  echo -e "${YELLOW}Создаем systemd override для сохранения разрешений при перезапуске Docker...${NC}"
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStartPost=/bin/chmod 666 /var/run/docker.sock
EOF
  systemctl daemon-reload
  echo -e "${GREEN}Systemd override создан${NC}"
fi

# Перезапускаем docker, если он работает
if systemctl is-active docker > /dev/null; then
  echo -e "${YELLOW}Перезапускаем службу Docker...${NC}"
  systemctl restart docker
  echo -e "${GREEN}Служба Docker перезапущена${NC}"
fi

echo -e "\n${GREEN}Исправления применены!${NC}"
echo -e "${YELLOW}Чтобы изменения вступили в силу для текущей сессии, выполните:${NC}"
echo -e "  ${GREEN}su - $CURRENT_USER${NC}"
echo -e "  ${GREEN}или${NC}"
echo -e "  ${GREEN}newgrp docker${NC}"
echo -e "${YELLOW}Или перезагрузите систему${NC}"
