/**
 * Класс для управления сессиями пользователей и сообщениями
 */
class SessionManager {
  /**
   * Создает новый экземпляр SessionManager
   * @param {object} dbClient Клиент базы данных (pg)
   */
  constructor(dbClient) {
    this.dbClient = dbClient;
  }
  
  /**
   * Создает новую сессию
   * @param {string} userId ID пользователя
   * @param {object} metadata Метаданные сессии
   * @returns {Promise<object>} Информация о созданной сессии
   */
  async createSession(userId, metadata = {}) {
    try {
      const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      
      const result = await this.dbClient.query(
        'INSERT INTO sessions (session_id, user_id, metadata) VALUES ($1, $2, $3) RETURNING *',
        [sessionId, userId, JSON.stringify(metadata)]
      );
      
      return result.rows[0];
    } catch (error) {
      console.error(`Failed to create session: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Получает информацию о сессии
   * @param {string} sessionId ID сессии
   * @returns {Promise<object>} Информация о сессии
   */
  async getSession(sessionId) {
    try {
      const result = await this.dbClient.query(
        'SELECT * FROM sessions WHERE session_id = $1',
        [sessionId]
      );
      
      if (result.rows.length === 0) {
        throw new Error(`Session ${sessionId} not found`);
      }
      
      return result.rows[0];
    } catch (error) {
      console.error(`Failed to get session: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Обновляет метаданные сессии
   * @param {string} sessionId ID сессии
   * @param {object} metadata Новые метаданные
   * @returns {Promise<object>} Обновленная информация о сессии
   */
  async updateSessionMetadata(sessionId, metadata) {
    try {
      const currentSession = await this.getSession(sessionId);
      const updatedMetadata = { ...currentSession.metadata, ...metadata };
      
      const result = await this.dbClient.query(
        'UPDATE sessions SET metadata = $1, updated_at = NOW() WHERE session_id = $2 RETURNING *',
        [JSON.stringify(updatedMetadata), sessionId]
      );
      
      return result.rows[0];
    } catch (error) {
      console.error(`Failed to update session metadata: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Добавляет сообщение в сессию
   * @param {string} sessionId ID сессии
   * @param {string} role Роль ('user', 'assistant', 'system')
   * @param {string} content Содержимое сообщения
   * @param {object} metadata Метаданные сообщения
   * @returns {Promise<object>} Информация о созданном сообщении
   */
  async addMessage(sessionId, role, content, metadata = {}) {
    try {
      // Обновляем время последнего взаимодействия с сессией
      await this.dbClient.query(
        'UPDATE sessions SET updated_at = NOW() WHERE session_id = $1',
        [sessionId]
      );
      
      // Добавляем сообщение
      const result = await this.dbClient.query(
        'INSERT INTO messages (session_id, role, content, metadata) VALUES ($1, $2, $3, $4) RETURNING *',
        [sessionId, role, content, JSON.stringify(metadata)]
      );
      
      return result.rows[0];
    } catch (error) {
      console.error(`Failed to add message: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Получает сообщения сессии
   * @param {string} sessionId ID сессии
   * @param {number} limit Максимальное количество сообщений
   * @param {string} order Порядок сортировки ('asc' или 'desc')
   * @returns {Promise<Array>} Массив сообщений
   */
  async getMessages(sessionId, limit = 50, order = 'asc') {
    try {
      const orderBy = order.toLowerCase() === 'desc' ? 'DESC' : 'ASC';
      
      const result = await this.dbClient.query(
        `SELECT * FROM messages 
         WHERE session_id = $1 
         ORDER BY created_at ${orderBy} 
         LIMIT $2`,
        [sessionId, limit]
      );
      
      return result.rows;
    } catch (error) {
      console.error(`Failed to get messages: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Получает сессии пользователя
   * @param {string} userId ID пользователя
   * @param {number} limit Максимальное количество сессий
   * @returns {Promise<Array>} Массив сессий
   */
  async getUserSessions(userId, limit = 10) {
    try {
      const result = await this.dbClient.query(
        'SELECT * FROM sessions WHERE user_id = $1 ORDER BY updated_at DESC LIMIT $2',
        [userId, limit]
      );
      
      return result.rows;
    } catch (error) {
      console.error(`Failed to get user sessions: ${error.message}`);
      throw error;
    }
  }
  
  /**
   * Форматирует сообщения для использования с API моделей (например, OpenAI)
   * @param {Array} messages Массив сообщений
   * @returns {Array} Отформатированные сообщения
   */
  formatMessagesForAPI(messages) {
    return messages.map(msg => ({
      role: msg.role,
      content: msg.content
    }));
  }
  
  /**
   * Получает контекст беседы для использования в промптах
   * @param {string} sessionId ID сессии
   * @param {number} maxMessages Максимальное количество сообщений
   * @returns {Promise<string>} Контекст беседы в виде строки
   */
  async getConversationContext(sessionId, maxMessages = 10) {
    try {
      const messages = await this.getMessages(sessionId, maxMessages);
      
      let context = 'История беседы:\n\n';
      
      for (const msg of messages) {
        const role = msg.role === 'assistant' ? 'AI' : (msg.role === 'user' ? 'Пользователь' : 'Система');
        context += `${role}: ${msg.content}\n\n`;
      }
      
      return context;
    } catch (error) {
      console.error(`Failed to get conversation context: ${error.message}`);
      return '';
    }
  }
}

module.exports = SessionManager;
