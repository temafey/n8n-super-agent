#!/bin/bash

# скрипт проверки безопасности n8n-super-agent
# Проверяет настройки безопасности после развертывания

# Цвета для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Функция для проверки статуса и вывода результата
check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ $1${NC}"
  else
    echo -e "${RED}✗ $1${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
}

# Функция для отображения заголовка секции
print_section() {
  echo -e "\n${BLUE}======================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}======================${NC}"
}

# Счетчик неудачных проверок
FAILED_CHECKS=0

echo -e "${YELLOW}Запускаю проверку безопасности для n8n-super-agent...${NC}"

# Проверка наличия docker
print_section "1. Проверка Docker"
docker --version > /dev/null 2>&1
check_status "Docker установлен"

# Проверка запущенных контейнеров
print_section "2. Проверка запущенных контейнеров"
CONTAINERS=$(docker ps --format '{{.Names}}' | grep -E 'n8n|postgres|redis|nginx|zep|weaviate|embeddings')
if [ -n "$CONTAINERS" ]; then
  echo -e "${GREEN}✓ Контейнеры запущены:${NC}"
  docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E 'n8n|postgres|redis|nginx|zep|weaviate|embeddings'
else
  echo -e "${RED}✗ Контейнеры не запущены${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка NGINX
print_section "3. Проверка NGINX SSL"
if docker ps --format '{{.Names}}' | grep -q nginx; then
  # Проверяем, содержит ли конфигурация NGINX настройки SSL
  SSL_CONFIG=$(docker exec $(docker ps -qf "name=nginx") grep -r "ssl_certificate" /etc/nginx/ 2>/dev/null)
  if [ -n "$SSL_CONFIG" ]; then
    echo -e "${GREEN}✓ NGINX SSL настроен${NC}"
    echo -e "$SSL_CONFIG"
  else
    echo -e "${RED}✗ NGINX SSL не настроен${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
else
  echo -e "${YELLOW}! Контейнер NGINX не запущен, пропускаю проверку SSL${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка UFW
print_section "4. Проверка UFW"
if command -v ufw > /dev/null 2>&1; then
  UFW_STATUS=$(sudo ufw status)
  if echo "$UFW_STATUS" | grep -q "Status: active"; then
    echo -e "${GREEN}✓ UFW активен${NC}"
    echo -e "$UFW_STATUS"
  else
    echo -e "${RED}✗ UFW не активен${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
else
  echo -e "${YELLOW}! UFW не установлен${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка Fail2Ban
print_section "5. Проверка Fail2Ban"
if command -v fail2ban-client > /dev/null 2>&1; then
  F2B_STATUS=$(sudo fail2ban-client status)
  if echo "$F2B_STATUS" | grep -q "Jail list:"; then
    echo -e "${GREEN}✓ Fail2Ban активен${NC}"
    # Проверка статуса jail sshd
    SSHD_STATUS=$(sudo fail2ban-client status sshd 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ Jail sshd активен${NC}"
      echo -e "$SSHD_STATUS"
    else
      echo -e "${RED}✗ Jail sshd не активен${NC}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
  else
    echo -e "${RED}✗ Fail2Ban не активен${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
else
  echo -e "${YELLOW}! Fail2Ban не установлен${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка SSH
print_section "6. Проверка конфигурации SSH"
if [ -f "/etc/ssh/sshd_config" ]; then
  # Проверка PasswordAuthentication
  PA_STATUS=$(grep -P "^PasswordAuthentication" /etc/ssh/sshd_config)
  if echo "$PA_STATUS" | grep -q "no"; then
    echo -e "${GREEN}✓ SSH PasswordAuthentication отключен${NC}"
  else
    # Проверка в подкаталоге sshd_config.d/
    if [ -d "/etc/ssh/sshd_config.d/" ]; then
      PA_STATUS_D=$(grep -P "^PasswordAuthentication" /etc/ssh/sshd_config.d/* 2>/dev/null | tail -1)
      if echo "$PA_STATUS_D" | grep -q "no"; then
        echo -e "${GREEN}✓ SSH PasswordAuthentication отключен в sshd_config.d/${NC}"
      else
        echo -e "${RED}✗ SSH PasswordAuthentication не отключен${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
      fi
    else
      echo -e "${RED}✗ SSH PasswordAuthentication не отключен${NC}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
  fi

  # Проверка PermitRootLogin
  ROOT_STATUS=$(grep -P "^PermitRootLogin" /etc/ssh/sshd_config)
  if echo "$ROOT_STATUS" | grep -q "no"; then
    echo -e "${GREEN}✓ SSH PermitRootLogin отключен${NC}"
  else
    # Проверка в подкаталоге sshd_config.d/
    if [ -d "/etc/ssh/sshd_config.d/" ]; then
      ROOT_STATUS_D=$(grep -P "^PermitRootLogin" /etc/ssh/sshd_config.d/* 2>/dev/null | tail -1)
      if echo "$ROOT_STATUS_D" | grep -q "no"; then
        echo -e "${GREEN}✓ SSH PermitRootLogin отключен в sshd_config.d/${NC}"
      else
        echo -e "${RED}✗ SSH PermitRootLogin не отключен${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
      fi
    else
      echo -e "${RED}✗ SSH PermitRootLogin не отключен${NC}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
  fi
else
  echo -e "${YELLOW}! Файл sshd_config не найден${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка Unattended Upgrades
print_section "7. Проверка Unattended Upgrades"
if dpkg -l | grep -q unattended-upgrades; then
  if [ -f "/etc/apt/apt.conf.d/20auto-upgrades" ]; then
    UU_STATUS=$(grep "Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades)
    if echo "$UU_STATUS" | grep -q "1"; then
      echo -e "${GREEN}✓ Unattended Upgrades активны${NC}"
    else
      echo -e "${RED}✗ Unattended Upgrades не активны${NC}"
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
  else
    echo -e "${RED}✗ 20auto-upgrades не найден${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
else
  echo -e "${YELLOW}! Unattended Upgrades не установлен${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка автоматического резервного копирования
print_section "8. Проверка настроек резервного копирования"
if crontab -l 2>/dev/null | grep -q "backup"; then
  echo -e "${GREEN}✓ Cron-задание для резервного копирования настроено${NC}"
  crontab -l | grep "backup"
else
  echo -e "${RED}✗ Cron-задание для резервного копирования не найдено${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Проверка .env файла
print_section "9. Проверка .env файла"
if [ -f ".env" ]; then
  # Проверка наличия дефолтных значений
  if grep -q "admin" .env; then
    echo -e "${RED}✗ В .env файле найдены дефолтные значения учетных данных${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  else
    echo -e "${GREEN}✓ В .env файле не обнаружены дефолтные значения${NC}"
  fi

  # Проверка прав доступа
  ENV_PERMS=$(stat -c "%a" .env)
  if [ "$ENV_PERMS" -le "600" ]; then
    echo -e "${GREEN}✓ Права доступа к .env файлу ограничены ($ENV_PERMS)${NC}"
  else
    echo -e "${RED}✗ Файл .env имеет слишком открытые права доступа ($ENV_PERMS)${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
else
  echo -e "${RED}✗ Файл .env не найден${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Итоговый результат
print_section "Результаты проверки безопасности"
if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}Все проверки пройдены успешно!${NC}"
  echo -e "${GREEN}Ваша система n8n-super-agent настроена безопасно.${NC}"
else
  echo -e "${RED}Не пройдено проверок: $FAILED_CHECKS${NC}"
  echo -e "${YELLOW}Рекомендуется исправить обнаруженные проблемы для повышения безопасности.${NC}"
  
  echo -e "\n${BLUE}Рекомендации:${NC}"
  echo -e "1. Проверьте файл .env и замените все дефолтные значения"
  echo -e "2. Убедитесь, что файл .env имеет права доступа 600"
  echo -e "3. Настройте UFW для ограничения доступа"
  echo -e "4. Настройте Fail2Ban для защиты от брутфорс-атак"
  echo -e "5. Настройте SSH для использования только ключей"
  echo -e "6. Включите автоматические обновления безопасности"
  echo -e "7. Настройте автоматическое резервное копирование"
fi

echo -e "\n${YELLOW}Для более подробной информации по безопасности см. раздел 'Безопасность' в README.md${NC}"
