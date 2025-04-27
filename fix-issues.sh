#!/bin/bash
echo "Исправление проблем в проекте n8n-super-agent..."

# 1. Монтирование lib в контейнер n8n
sed -i 's|- ./workflows:/home/node/.n8n/workflows|- ./workflows:/home/node/.n8n/workflows\n      - ./lib:/home/node/.n8n/lib|g' docker-compose.yml

# 2. Исправление имени переменной в Weaviate
sed -i 's|OPENAI_APIKEY=${OPENAI_API_KEY}|OPENAI_API_KEY=${OPENAI_API_KEY}|g' docker-compose.yml

# 3. Создание директорий для логов
mkdir -p logs/n8n logs/zep logs/postgres logs/postgres-zep logs/redis logs/nginx logs/weaviate
mkdir -p nginx/certs nginx/conf.d

# 4. Создание скрипта для инициализации Weaviate
cat > lib/init-weaviate.js << 'EOL'
const fetch = require('node-fetch');

async function waitForWeaviate(retries = 10, delay = 5000) {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch('http://weaviate:8080/v1/.well-known/ready');
      if (response.ok) {
        console.log('Weaviate готов!');
        return true;
      }
    } catch (e) {
      console.log(`Weaviate не готов, ожидание... (${i+1}/${retries})`);
    }
    await new Promise(resolve => setTimeout(resolve, delay));
  }
  throw new Error('Weaviate не запустился за отведенное время');
}

const { initializeWeaviateSchema } = require('./weaviate-schema');

async function init() {
  try {
    await waitForWeaviate();
    await initializeWeaviateSchema();
    console.log('Схема Weaviate успешно инициализирована');
  } catch (error) {
    console.error('Ошибка инициализации схемы Weaviate:', error);
  }
}

init();
EOL

# 5. Обновление скрипта setup.sh
cat > setup.sh.new << 'EOL'
#!/bin/bash

echo "Инициализация n8n супер-агента..."

# Определение директории скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Проверка наличия Docker и Docker Compose
if ! command -v docker &> /dev/null
then
    echo "Docker не установлен. Пожалуйста, установите Docker и Docker Compose."
    exit 1
fi

if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose не установлен. Пожалуйста, установите Docker Compose."
    exit 1
fi

# Создание необходимых директорий
mkdir -p "$SCRIPT_DIR/logs/n8n" "$SCRIPT_DIR/logs/zep" "$SCRIPT_DIR/logs/postgres" "$SCRIPT_DIR/logs/postgres-zep" "$SCRIPT_DIR/logs/redis" "$SCRIPT_DIR/logs/nginx" "$SCRIPT_DIR/logs/weaviate"
mkdir -p "$SCRIPT_DIR/nginx/certs" "$SCRIPT_DIR/nginx/conf.d"
mkdir -p "$SCRIPT_DIR/workflows/prompts" "$SCRIPT_DIR/workflows/templates"

# Проверка .env файла
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Файл .env не найден. Создаем из шаблона..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo "Пожалуйста, отредактируйте файл .env и установите правильные значения API ключей."
fi

# Создание самоподписанных SSL-сертификатов, если их нет
if [ ! -f "$SCRIPT_DIR/nginx/certs/server.crt" ]; then
    echo "Создаем самоподписанные SSL сертификаты..."
    mkdir -p "$SCRIPT_DIR/nginx/certs"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/nginx/certs/server.key" -out "$SCRIPT_DIR/nginx/certs/server.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
fi

# Запуск Docker Compose
echo "Запуск контейнеров..."
cd "$SCRIPT_DIR" && docker-compose up -d

# Ожидание запуска сервисов
echo "Ожидание запуска сервисов..."
sleep 15

# Инициализация Weaviate
echo "Инициализация схемы Weaviate..."
docker exec -w /home/node/.n8n $(docker ps -qf "name=n8n-super-agent_n8n") node lib/init-weaviate.js

# Ожидаем завершения инициализации
sleep 5

# Получение токена API n8n
echo "Получение API токена n8n..."
N8N_API_KEY=$(docker exec $(docker ps -qf "name=n8n-super-agent_n8n") n8n user:api:create --first-user)
echo "API токен n8n: $N8N_API_KEY"

# Импорт шаблонов workflows
echo "Импорт шаблонов workflows..."
for template in "$SCRIPT_DIR/workflows/templates/"*.json; do
  if [ -f "$template" ]; then
    filename=$(basename -- "$template")
    echo "Импорт шаблона: $filename"
    curl -X POST "http://localhost:5678/rest/workflows" \
      -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" \
      -d @"$template"
  fi
done

# Инициализация БД
echo "Инициализация базы данных..."
docker exec -i $(docker ps -qf "name=n8n-super-agent_postgres") psql -U n8n -d n8n < "$SCRIPT_DIR/init-db.sql"

echo "Установка завершена!"
echo "n8n доступен по адресу: https://localhost"
echo "Учетные данные по умолчанию: admin/admin (изменить в .env файле)"
echo ""
echo "Рекомендации:"
echo "1. Отредактируйте файл .env и установите безопасные пароли и API ключи"
echo "2. Создайте и импортируйте ваши собственные workflows"
echo "3. Для промышленного использования настройте правильные SSL-сертификаты"
EOL

# Замена старого setup.sh на новый
mv setup.sh.new setup.sh
chmod +x setup.sh

# 6. Создание Dockerfile для n8n
cat > Dockerfile.n8n << 'EOL'
FROM n8nio/n8n:latest

WORKDIR /home/node

# Копируем package.json и устанавливаем зависимости
COPY package.json .
RUN npm install

# Возвращаемся в рабочую директорию n8n
WORKDIR /home/node/.n8n
EOL

# 7. Обновление docker-compose.yml для использования кастомного образа
sed -i 's|image: n8nio/n8n:latest|build:\n      context: .\n      dockerfile: Dockerfile.n8n|g' docker-compose.yml

# 8. Обновление класса RedisCache для поддержки повторных попыток подключения
cat > lib/redis-cache.new.js << 'EOL'
const Redis = require('redis');

/**
 * Класс для управления кэшированием через Redis
 */
class RedisCache {
  /**
   * Создает новый экземпляр RedisCache
   * @param {object} options Параметры подключения к Redis
   */
  constructor(options = {}) {
    const { host = 'redis', port = 6379, password, db = 0 } = options;
    
    this.client = Redis.createClient({
      url: `redis://${password ? `:${password}@` : ''}${host}:${port}/${db}`
    });
    
    this.client.on('error', (err) => {
      console.error('Redis Error:', err);
    });
    
    this.connected = false;
    this.connect();
  }
  
  /**
   * Устанавливает соединение с Redis
   * @param {number} retries Количество попыток
   * @param {number} delay Задержка между попытками в мс
   */
  async connect(retries = 5, delay = 2000) {
    if (this.connected) return;
    
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await this.client.connect();
        this.connected = true;
        console.log('Connected to Redis');
        return;
      } catch (error) {
        console.error(`Failed to connect to Redis (attempt ${attempt}/${retries}):`, error);
        if (attempt < retries) {
          console.log(`Retrying in ${delay/1000} seconds...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }
    
    console.error(`Failed to connect to Redis after ${retries} attempts`);
  }
EOL

# Копируем остальную часть файла redis-cache.js
tail -n +42 lib/redis-cache.js >> lib/redis-cache.new.js

# Заменяем файл
mv lib/redis-cache.new.js lib/redis-cache.js

# 9. Обновление weaviate-client.js для более надежной обработки ошибок
sed -i 's|return result.data.Get\[className\] || \[\];|return (result.data && result.data.Get && result.data.Get[className]) ? result.data.Get[className] : [];|g' lib/weaviate-client.js

# 10. Создание скрипта для обновления путей в шаблонах workflows
cat > update-workflow-paths.js << 'EOL'
const fs = require('fs');
const path = require('path');

const templatesDir = path.join(__dirname, 'workflows', 'templates');
const files = fs.readdirSync(templatesDir);

files.forEach(file => {
  if (file.endsWith('.json')) {
    const filePath = path.join(templatesDir, file);
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Обновляем относительные пути на абсолютные
    content = content.replace(/require\('\.\.\/lib\//g, "require('/home/node/.n8n/lib/");
    
    // Обновляем локализацию для веб-поиска
    if (file === 'web-search.json') {
      const localeCode = `// Маппинг языков на локали
const languageToLocale = {
  'русский': 'ru-ru',
  'английский': 'en-us',
  'испанский': 'es-es',
  'французский': 'fr-fr',
  'немецкий': 'de-de'
};

const locale = languageToLocale[$input.language] || 'ru-ru';

const searchResults = await search(query, {
  safeSearch: 'moderate',
  locale: locale,
  time: 'y' // За последний год
});`;
      
      content = content.replace(/const searchResults = await search\(query, \{[\s\S]*?time: 'y'[\s\S]*?\}\);/, localeCode);
    }
    
    fs.writeFileSync(filePath, content);
    console.log(`Обновлен файл: ${file}`);
  }
});
EOL

# Запускаем скрипт для обновления путей
node update-workflow-paths.js

echo "Исправления успешно применены!"
echo "Рекомендуется перезапустить проект с помощью команды: ./setup.sh"
