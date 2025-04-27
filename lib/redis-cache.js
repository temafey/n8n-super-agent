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
  
  /**
   * Закрывает соединение с Redis
   */
  async disconnect() {
    if (this.connected) {
      try {
        await this.client.quit();
        this.connected = false;
        console.log('Disconnected from Redis');
      } catch (error) {
        console.error('Failed to disconnect from Redis:', error);
      }
    }
  }
  
  /**
   * Получает значение из кэша
   * @param {string} key Ключ
   * @returns {Promise<any>} Значение из кэша
   */
  async get(key) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      const value = await this.client.get(key);
      return value ? JSON.parse(value) : null;
    } catch (error) {
      console.error(`Redis get error for key ${key}:`, error);
      return null;
    }
  }
  
  /**
   * Сохраняет значение в кэш
   * @param {string} key Ключ
   * @param {any} value Значение
   * @param {number} ttl Время жизни в секундах
   * @returns {Promise<boolean>} Успешность операции
   */
  async set(key, value, ttl = 3600) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      const serializedValue = JSON.stringify(value);
      if (ttl > 0) {
        await this.client.setEx(key, ttl, serializedValue);
      } else {
        await this.client.set(key, serializedValue);
      }
      return true;
    } catch (error) {
      console.error(`Redis set error for key ${key}:`, error);
      return false;
    }
  }
  
  /**
   * Удаляет значение из кэша
   * @param {string} key Ключ
   * @returns {Promise<boolean>} Успешность операции
   */
  async delete(key) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      await this.client.del(key);
      return true;
    } catch (error) {
      console.error(`Redis delete error for key ${key}:`, error);
      return false;
    }
  }
  
  /**
   * Проверяет существование ключа
   * @param {string} key Ключ
   * @returns {Promise<boolean>} Существует ли ключ
   */
  async exists(key) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      const exists = await this.client.exists(key);
      return exists === 1;
    } catch (error) {
      console.error(`Redis exists error for key ${key}:`, error);
      return false;
    }
  }
  
  /**
   * Получает оставшееся время жизни ключа в секундах
   * @param {string} key Ключ
   * @returns {Promise<number>} Оставшееся время в секундах (-1 если бессрочно, -2 если не существует)
   */
  async ttl(key) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      return await this.client.ttl(key);
    } catch (error) {
      console.error(`Redis ttl error for key ${key}:`, error);
      return -2;
    }
  }
  
  /**
   * Устанавливает время жизни ключа
   * @param {string} key Ключ
   * @param {number} seconds Время в секундах
   * @returns {Promise<boolean>} Успешность операции
   */
  async expire(key, seconds) {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      const result = await this.client.expire(key, seconds);
      return result === 1;
    } catch (error) {
      console.error(`Redis expire error for key ${key}:`, error);
      return false;
    }
  }
  
  /**
   * Очищает все кэшированные данные
   * @returns {Promise<boolean>} Успешность операции
   */
  async clear() {
    if (!this.connected) {
      await this.connect();
    }
    
    try {
      await this.client.flushDb();
      return true;
    } catch (error) {
      console.error('Redis clear error:', error);
      return false;
    }
  }
  
  /**
   * Интеллектуальное кэширование: получает значение из кэша или вызывает функцию для получения значения
   * @param {string} key Ключ кэша
   * @param {Function} getValueFn Функция для получения значения (async)
   * @param {object} options Опции кэширования
   * @returns {Promise<object>} Результат с индикацией источника данных
   */
  async intelligentCache(key, getValueFn, options = {}) {
    // Опции кэширования
    const ttl = options.ttl || 3600; // Время жизни кэша в секундах (по умолчанию 1 час)
    const prefix = options.prefix || 'cache:';
    const bypassCache = options.bypassCache || false;
    
    // Полный ключ кэша
    const fullKey = `${prefix}${key}`;
    
    // Проверяем наличие значения в кэше
    if (!bypassCache) {
      try {
        const cachedValue = await this.get(fullKey);
        
        if (cachedValue) {
          // Проверяем срок годности кэша
          if (cachedValue.timestamp && (Date.now() - cachedValue.timestamp) / 1000 < ttl) {
            return {
              value: cachedValue.value,
              source: 'cache',
              age: Math.round((Date.now() - cachedValue.timestamp) / 1000),
              key: fullKey
            };
          }
        }
      } catch (error) {
        console.log(`Cache read error: ${error.message}`);
      }
    }
    
    // Если значения нет в кэше или оно устарело, получаем новое значение
    try {
      const value = await getValueFn();
      
      // Сохраняем новое значение в кэш
      const cacheEntry = {
        value,
        timestamp: Date.now()
      };
      
      await this.set(fullKey, cacheEntry, ttl);
      
      return {
        value,
        source: 'fresh',
        key: fullKey
      };
    } catch (error) {
      throw new Error(`Value generation failed: ${error.message}`);
    }
  }
}

module.exports = RedisCache;
