#!/bin/bash

# Цвета для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

echo -e "${GREEN}Удаление лишних свойств из файлов workflow...${NC}"

# Директория с шаблонами workflows
TEMPLATES_DIR="./workflows/templates"

# Параметры командной строки
FILE_TO_PROCESS=""
FORCE_MODE=false

# Обработка параметров командной строки
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--file) FILE_TO_PROCESS="$2"; shift ;;
        --force) FORCE_MODE=true ;;
        -h|--help)
            echo "Использование: $0 [опции]"
            echo "Опции:"
            echo "  -f, --file ФАЙЛ     Обработать только указанный файл"
            echo "  --force             Принудительно обновить все файлы, даже если изменений нет"
            echo "  -h, --help          Показать эту справку"
            exit 0
            ;;
        *) echo "Неизвестный параметр: $1"; exit 1 ;;
    esac
    shift
done

# Проверяем наличие директории
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo -e "${RED}Директория $TEMPLATES_DIR не существует!${NC}"
    mkdir -p "$TEMPLATES_DIR"
    echo -e "${YELLOW}Директория создана.${NC}"
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

# Список разрешенных свойств верхнего уровня в workflow n8n
# Удаляем 'meta' из списка разрешенных свойств, так как оно вызывает ошибку при импорте
ALLOWED_PROPS=("name" "nodes" "connections" "settings" "staticData" "active" "pinData" "versionId" "tags")

# Если указан конкретный файл, обрабатываем только его
if [ -n "$FILE_TO_PROCESS" ]; then
    if [[ "$FILE_TO_PROCESS" != *"/"* ]]; then
        # Если указано только имя файла без пути, добавляем путь
        FILE_TO_PROCESS="$TEMPLATES_DIR/$FILE_TO_PROCESS"
    fi

    if [ ! -f "$FILE_TO_PROCESS" ]; then
        echo -e "${RED}Файл $FILE_TO_PROCESS не найден!${NC}"
        exit 1
    fi

    FILES_TO_PROCESS=("$FILE_TO_PROCESS")
else
    # Проверяем наличие JSON-файлов
    JSON_FILES=$(find "$TEMPLATES_DIR" -name "*.json")
    if [ -z "$JSON_FILES" ]; then
        echo -e "${YELLOW}В директории $TEMPLATES_DIR нет JSON-файлов${NC}"
        exit 1
    fi

    # Список всех JSON-файлов в директории
    FILES_TO_PROCESS=($JSON_FILES)
fi

# Счетчики
total_files=0
processed_files=0
error_files=0

# Проходим по всем JSON-файлам
for file in "${FILES_TO_PROCESS[@]}"; do
    ((total_files++))
    filename=$(basename "$file" .json)
    echo -e "\n${YELLOW}Обработка файла: ${NC}$filename.json"

    # Создаем резервную копию файла
    cp "$file" "${file}.bak"

    # Проверяем валидность JSON
    if ! jq empty "$file" 2>/dev/null; then
        echo -e "  ${RED}✗ Некорректный JSON, попытка исправить...${NC}"

        # Простые исправления синтаксиса JSON
        content=$(cat "$file")

        # Удаление комментариев
        content=$(echo "$content" | sed '/\/\//d' | sed '/\/\*.*\*\//d')

        # Исправление отсутствующих запятых
        content=$(echo "$content" | sed 's/\([^,{[]\)\s*\n\s*\([\]}]\)/\1,\n\2/g')

        # Исправление отсутствующих кавычек вокруг ключей
        content=$(echo "$content" | sed 's/\([{,]\)\s*\([a-zA-Z0-9_]*\)\s*:/\1"\2":/g')

        # Записываем исправленный контент
        echo "$content" > "$file"

        # Проверяем, исправлен ли JSON
        if ! jq empty "$file" 2>/dev/null; then
            echo -e "  ${RED}✗ Не удалось исправить JSON, восстанавливаем из резервной копии${NC}"
            mv "${file}.bak" "$file"
            ((error_files++))
            continue
        else
            echo -e "  ${GREEN}✓ JSON синтаксис исправлен${NC}"
        fi
    fi

    # Получаем все поля верхнего уровня до изменений
    properties_before=$(jq -r 'keys[]' "$file")

    # Создаем временный файл с обработанным JSON
    workflow_name="${filename} Workflow"

    # Используем файловый дескриптор для создания строки скрипта для jq
    jq_script=$(cat <<EOT
{
  name: (if has("name") then .name else "${workflow_name}" end),
  nodes: (if has("nodes") then .nodes else [] end),
  connections: (if has("connections") then
    if (.connections | type) == "array" then {} else .connections end
  else {} end),
  settings: (if has("settings") then .settings else {
    saveExecutionProgress: true,
    saveManualExecutions: true,
    saveDataErrorExecution: "all",
    saveDataSuccessExecution: "all"
  } end),
  staticData: (if has("staticData") then .staticData else null end),
  active: (if has("active") then .active else null end),
  pinData: (if has("pinData") then .pinData else null end),
  versionId: (if has("versionId") then .versionId else null end),
  tags: (if has("tags") then .tags else null end)
} | with_entries(select(.value != null))
EOT
)

    # Применяем jq-скрипт к файлу
    jq "$jq_script" "$file" > "${file}.tmp"

    # Файл изменен или принудительный режим?
    changes_made=false
    if ! diff -q "$file" "${file}.tmp" > /dev/null || [ "$FORCE_MODE" = true ]; then
        changes_made=true

        # Получаем удаленные поля
        if [ "$FORCE_MODE" = false ]; then
            # Получаем поля после изменений
            properties_after=$(jq -r 'keys[]' "${file}.tmp")

            # Находим удаленные поля
            removed_props=""
            for prop in $properties_before; do
                if ! grep -q "^$prop$" <(echo "$properties_after"); then
                    removed_props+="$prop"$'\n'
                fi
            done

            if [ -n "$removed_props" ]; then
                echo -e "  ${YELLOW}Удалены свойства верхнего уровня:${NC}"
                echo "$removed_props" | sed 's/^/    - /'
            fi
        fi

        # Перемещаем обработанный файл
        mv "${file}.tmp" "$file"
    else
        # Нет изменений, удаляем временный файл
        rm "${file}.tmp"
    fi

    # Проверка на наличие всех обязательных полей после обработки
    missing_fields=false
    for field in "name" "nodes" "connections" "settings"; do
        if ! jq -e ".$field" "$file" > /dev/null 2>&1; then
            echo -e "  ${RED}✗ Поле $field всё еще отсутствует!${NC}"
            missing_fields=true
        fi
    done

    # Проверка структуры после всех изменений
    final_properties=$(jq -r 'keys[]' "$file")
    invalid_props=""
    for prop in $final_properties; do
        prop_valid=false
        for allowed in "${ALLOWED_PROPS[@]}"; do
            if [ "$prop" = "$allowed" ]; then
                prop_valid=true
                break
            fi
        done

        if [ "$prop_valid" = false ]; then
            invalid_props+="$prop"$'\n'
        fi
    done

    if [ -n "$invalid_props" ]; then
        echo -e "  ${RED}✗ В файле остались неразрешенные свойства:${NC}"
        echo "$invalid_props" | sed 's/^/    - /'
        changes_made=true

        # Еще раз применяем jq-скрипт для удаления неразрешенных свойств
        jq "$jq_script" "$file" > "${file}.tmp"
        mv "${file}.tmp" "$file"
        echo -e "  ${GREEN}✓ Повторно удалены неразрешенные свойства${NC}"
    fi

    # Итоговый статус
    if [ "$changes_made" = true ]; then
        if [ "$missing_fields" = false ]; then
            echo -e "  ${GREEN}✓ Файл успешно обработан${NC}"
            ((processed_files++))
        else
            echo -e "  ${RED}✗ Не удалось добавить все обязательные поля${NC}"
            ((error_files++))
        fi
    else
        echo -e "  ${GREEN}✓ Файл не требует изменений${NC}"
        ((processed_files++))
    fi

    # Удаляем резервную копию, если всё в порядке
    if [ "$missing_fields" = false ]; then
        rm "${file}.bak"
    else
        echo -e "  ${YELLOW}⚠ Сохранена резервная копия ${file}.bak${NC}"
    fi
done

echo -e "\n${GREEN}Обработка завершена!${NC}"
echo -e "Всего файлов: $total_files"
echo -e "Успешно обработано: $processed_files"
echo -e "С ошибками: $error_files"

if [ "$processed_files" -gt 0 ]; then
    echo -e "\n${YELLOW}Импортируйте workflow командой:${NC}"

    if [ -n "$FILE_TO_PROCESS" ]; then
        echo -e "./import-workflows.sh $(basename "$FILE_TO_PROCESS")"
    else
        echo -e "./import-workflows.sh"
    fi
fi