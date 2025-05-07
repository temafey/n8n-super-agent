#!/bin/bash

# Скрипт для проверки и исправления JSON-файлов workflow n8n

# Цвета для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

echo -e "${GREEN}Начинаю проверку workflow в n8n...${NC}"

# Директория с шаблонами workflows
TEMPLATES_DIR="./workflows/templates"

# Проверяем наличие директории
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo -e "${RED}Директория $TEMPLATES_DIR не существует!${NC}"
    mkdir -p "$TEMPLATES_DIR"
    echo -e "${YELLOW}Директория создана. Пожалуйста, добавьте в нее JSON-файлы workflow.${NC}"
    exit 1
fi

# Проверяем, есть ли JSON-файлы в директории
JSON_FILES=$(find "$TEMPLATES_DIR" -name "*.json")
if [ -z "$JSON_FILES" ]; then
    echo -e "${RED}В директории $TEMPLATES_DIR нет JSON-файлов!${NC}"
    exit 1
fi

# Проверяем наличие утилиты jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Утилита jq не установлена!${NC}"
    echo -e "Установите её с помощью:"
    echo -e "  apt-get install jq (Debian/Ubuntu)"
    echo -e "  brew install jq (macOS)"
    echo -e "  dnf install jq (Fedora)"
    exit 1
fi

# Счетчики ошибок
valid_files=0
invalid_files=0
fixed_files=0

# Проходим по всем JSON-файлам
for file in $JSON_FILES; do
    echo -e "\n${YELLOW}Проверка файла: ${NC}$(basename "$file")"

    # Проверяем валидность JSON
    if jq empty "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓ JSON валиден${NC}"

        # Проверяем наличие обязательных полей
        if jq -e '.name' "$file" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Поле 'name' присутствует${NC}"
        else
            echo -e "  ${RED}✗ Поле 'name' отсутствует${NC}"
            echo -e "  ${YELLOW}⚙ Добавляю поле 'name'${NC}"

            # Получаем имя файла без расширения для использования в качестве имени workflow
            filename=$(basename "$file" .json)

            # Создаем временный файл с добавленным полем name
            jq '. + {"name": "'"$filename"'"}' "$file" > "${file}.tmp"
            mv "${file}.tmp" "$file"

            echo -e "  ${GREEN}✓ Поле 'name' добавлено${NC}"
            ((fixed_files++))
        fi

        # Проверяем наличие массива nodes
        if jq -e '.nodes' "$file" >/dev/null 2>&1; then
            nodes_count=$(jq '.nodes | length' "$file")
            echo -e "  ${GREEN}✓ Массив 'nodes' присутствует (элементов: $nodes_count)${NC}"

            # Если массив nodes пустой, предупреждаем
            if [ "$nodes_count" -eq 0 ]; then
                echo -e "  ${YELLOW}⚠ Массив 'nodes' пустой${NC}"
            fi

            # Проверяем ID и типы узлов
            invalid_nodes=0
            for i in $(seq 0 $((nodes_count-1))); do
                node_name=$(jq -r ".nodes[$i].name // \"Без имени\"" "$file")

                # Проверяем наличие ID
                if ! jq -e ".nodes[$i].id" "$file" >/dev/null 2>&1; then
                    echo -e "  ${RED}✗ Узел '$node_name' не имеет ID${NC}"
                    echo -e "  ${YELLOW}⚙ Генерирую ID для узла '$node_name'${NC}"

                    # Генерируем UUID для узла
                    uuid=$(uuidgen || cat /proc/sys/kernel/random/uuid)

                    # Обновляем JSON с новым ID
                    jq ".nodes[$i] += {\"id\": \"$uuid\"}" "$file" > "${file}.tmp"
                    mv "${file}.tmp" "$file"

                    echo -e "  ${GREEN}✓ ID добавлен для узла '$node_name'${NC}"
                    ((fixed_files++))
                    ((invalid_nodes++))
                fi

                # Проверяем наличие типа узла
                if ! jq -e ".nodes[$i].type" "$file" >/dev/null 2>&1; then
                    echo -e "  ${RED}✗ Узел '$node_name' не имеет типа${NC}"
                    ((invalid_nodes++))
                fi

                # Проверяем наличие position
                if ! jq -e ".nodes[$i].position" "$file" >/dev/null 2>&1; then
                    echo -e "  ${RED}✗ Узел '$node_name' не имеет position${NC}"
                    echo -e "  ${YELLOW}⚙ Добавляю position для узла '$node_name'${NC}"

                    # Устанавливаем позицию по умолчанию
                    jq ".nodes[$i] += {\"position\": [$i*150, 0]}" "$file" > "${file}.tmp"
                    mv "${file}.tmp" "$file"

                    echo -e "  ${GREEN}✓ Position добавлен для узла '$node_name'${NC}"
                    ((fixed_files++))
                    ((invalid_nodes++))
                fi
            done

            if [ "$invalid_nodes" -eq 0 ]; then
                echo -e "  ${GREEN}✓ Все узлы имеют корректную структуру${NC}"
            fi
        else
            echo -e "  ${RED}✗ Массив 'nodes' отсутствует${NC}"
            echo -e "  ${YELLOW}⚙ Добавляю пустой массив 'nodes'${NC}"

            # Добавляем пустой массив nodes
            jq '. + {"nodes": []}' "$file" > "${file}.tmp"
            mv "${file}.tmp" "$file"

            echo -e "  ${GREEN}✓ Пустой массив 'nodes' добавлен${NC}"
            ((fixed_files++))
        fi

        # Проверяем наличие объекта connections
        if jq -e '.connections' "$file" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Объект 'connections' присутствует${NC}"
        else
            echo -e "  ${RED}✗ Объект 'connections' отсутствует${NC}"
            echo -e "  ${YELLOW}⚙ Добавляю пустой объект 'connections'${NC}"

            # Добавляем пустой объект connections
            jq '. + {"connections": {}}' "$file" > "${file}.tmp"
            mv "${file}.tmp" "$file"

            echo -e "  ${GREEN}✓ Пустой объект 'connections' добавлен${NC}"
            ((fixed_files++))
        fi

        # Проверяем наличие объекта settings
        if jq -e '.settings' "$file" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Объект 'settings' присутствует${NC}"

            # Проверяем ссылку на errorWorkflow
            if jq -e '.settings.errorWorkflow' "$file" >/dev/null 2>&1; then
                echo -e "  ${YELLOW}⚠ Найдена ссылка на errorWorkflow, убедитесь, что он существует${NC}"

                # Предлагаем удалить ссылку на errorWorkflow, так как она может быть недействительной
                read -p "  Удалить ссылку на errorWorkflow? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    jq 'del(.settings.errorWorkflow)' "$file" > "${file}.tmp"
                    mv "${file}.tmp" "$file"
                    echo -e "  ${GREEN}✓ Ссылка на errorWorkflow удалена${NC}"
                    ((fixed_files++))
                fi
            fi
        else
            echo -e "  ${RED}✗ Объект 'settings' отсутствует${NC}"
            echo -e "  ${YELLOW}⚙ Добавляю объект 'settings' по умолчанию${NC}"

            # Добавляем объект settings с минимальными настройками
            jq '. + {"settings": {"saveExecutionProgress": true, "saveManualExecutions": true}}' "$file" > "${file}.tmp"
            mv "${file}.tmp" "$file"

            echo -e "  ${GREEN}✓ Объект 'settings' по умолчанию добавлен${NC}"
            ((fixed_files++))
        fi

        # Проверяем ссылки на учетные данные
        credentials_count=$(jq '[.. | objects | select(has("credentials")) | .credentials] | length' "$file")
        if [ "$credentials_count" -gt 0 ]; then
            echo -e "  ${YELLOW}⚠ Найдены ссылки на учетные данные ($credentials_count)${NC}"
            echo -e "  ${YELLOW}⚠ Убедитесь, что все учетные данные существуют в вашей системе${NC}"

            # Предлагаем удалить все ссылки на учетные данные
            read -p "  Удалить все ссылки на учетные данные? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                jq 'walk(if type == "object" and has("credentials") then del(.credentials) else . end)' "$file" > "${file}.tmp"
                mv "${file}.tmp" "$file"
                echo -e "  ${GREEN}✓ Все ссылки на учетные данные удалены${NC}"
                ((fixed_files++))
            fi
        else
            echo -e "  ${GREEN}✓ Ссылки на учетные данные отсутствуют${NC}"
        fi

        ((valid_files++))
    else
        echo -e "  ${RED}✗ Некорректный JSON!${NC}"
        ((invalid_files++))

        # Попытка исправить простые синтаксические ошибки
        echo -e "  ${YELLOW}⚙ Попытка исправить синтаксис JSON...${NC}"

        # Создаем резервную копию файла
        cp "$file" "${file}.bak"

        # Простые исправления распространенных ошибок
        content=$(cat "$file")

        # Удаление комментариев
        content=$(echo "$content" | sed '/\/\//d' | sed '/\/\*.*\*\//d')

        # Исправление отсутствующих запятых в массивах и объектах
        content=$(echo "$content" | sed 's/\([^,{[]\)\s*\n\s*\([\]}]\)/\1,\n\2/g')

        # Исправление отсутствующих кавычек вокруг ключей
        content=$(echo "$content" | sed 's/\([{,]\)\s*\([a-zA-Z0-9_]*\)\s*:/\1"\2":/g')

        # Записываем исправленный контент
        echo "$content" > "$file"

        # Проверяем, исправлен ли файл
        if jq empty "$file" 2>/dev/null; then
            echo -e "  ${GREEN}✓ JSON успешно исправлен${NC}"
            ((fixed_files++))
            ((valid_files++))
            ((invalid_files--))
        else
            echo -e "  ${RED}✗ Не удалось исправить JSON автоматически${NC}"
            echo -e "  ${YELLOW}⚠ Восстанавливаю исходный файл${NC}"
            mv "${file}.bak" "$file"
            echo -e "  ${YELLOW}⚙ Проверьте файл вручную на наличие ошибок синтаксиса${NC}"
        fi
    fi
done

echo -e "\n${GREEN}Проверка завершена!${NC}"
echo -e "${GREEN}Валидных файлов: $valid_files${NC}"
echo -e "${RED}Невалидных файлов: $invalid_files${NC}"
echo -e "${YELLOW}Исправленных файлов: $fixed_files${NC}"

if [ "$invalid_files" -gt 0 ]; then
    echo -e "\n${RED}В некоторых файлах остались ошибки, которые не удалось исправить автоматически.${NC}"
    echo -e "${YELLOW}Проверьте эти файлы вручную на наличие синтаксических ошибок.${NC}"
fi

# Проверяем файл с API-ключом
echo -e "\n${YELLOW}Проверка файла с API-ключом...${NC}"
if [ ! -f ".n8n_api_key" ]; then
    echo -e "${RED}Файл .n8n_api_key не найден!${NC}"
    echo -e "${YELLOW}Вам нужно создать этот файл с вашим API-ключом n8n.${NC}"
    echo -e "${YELLOW}Получите API-ключ из интерфейса n8n (Settings -> API) и сохраните его в файл .n8n_api_key${NC}"
else
    api_key=$(cat .n8n_api_key)
    if [ -z "$api_key" ]; then
        echo -e "${RED}API-ключ пустой!${NC}"
        echo -e "${YELLOW}Обновите файл .n8n_api_key с правильным API-ключом.${NC}"
    else
        # Удаляем пробелы и переносы строк
        api_key=$(echo "$api_key" | tr -d '[:space:]')
        echo "$api_key" > .n8n_api_key
        echo -e "${GREEN}API-ключ найден и очищен от пробелов.${NC}"

        # Проверяем формат API-ключа (обычно это длинная строка с буквами и цифрами)
        if [[ ! $api_key =~ ^[a-zA-Z0-9]{30,}$ ]]; then
            echo -e "${YELLOW}⚠ Формат API-ключа может быть некорректным. Проверьте его в интерфейсе n8n.${NC}"
        fi
    fi
fi

# Проверяем скрипты импорта
echo -e "\n${YELLOW}Проверка скриптов импорта...${NC}"

if [ -f "import-workflows.sh" ]; then
    echo -e "${GREEN}Файл import-workflows.sh найден.${NC}"

    # Делаем скрипт исполняемым
    chmod +x import-workflows.sh

    # Проверяем URL API в скрипте
    echo -e "${YELLOW}Пожалуйста, убедитесь, что URL API в скрипте import-workflows.sh корректен:${NC}"
    grep -A 5 "API_URL" import-workflows.sh
else
    echo -e "${RED}Файл import-workflows.sh не найден!${NC}"
fi

if [ -f "import-templates.sh" ]; then
    echo -e "${GREEN}Файл import-templates.sh найден.${NC}"

    # Делаем скрипт исполняемым
    chmod +x import-templates.sh
else
    echo -e "${RED}Файл import-templates.sh не найден!${NC}"
fi

echo -e "\n${GREEN}Рекомендации для импорта workflow:${NC}"
echo -e "1. Убедитесь, что n8n запущен и доступен:"
echo -e "   ${YELLOW}make status${NC}"
echo -e "2. Проверьте, что API-ключ n8n корректен и актуален"
echo -e "3. Запустите импорт с подробным выводом:"
echo -e "   ${YELLOW}./import-workflows.sh 2>&1 | tee import-log.txt${NC}"
echo -e "4. Анализируйте лог на наличие ошибок"
echo -e "5. Исправьте ошибки в конкретных файлах workflow и повторите импорт"