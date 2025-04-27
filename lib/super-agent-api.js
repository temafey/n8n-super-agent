const fetch = require('node-fetch');

/**
 * Клиент API для взаимодействия с супер-агентом
 */
class SuperAgentAPI {
  /**
   * Создает новый экземпляр SuperAgentAPI
   * @param {object} options Опции подключения
   */
  constructor(options = {}) {
    this.baseUrl = options.baseUrl || 'http://localhost:5678/webhook';
    this.defaultUserId = options.userId || 'anonymous';
    this.sessionId = options.sessionId || null;
  }
  
  /**
   * Отправляет запрос супер-агенту
   * @param {string} query Запрос пользователя
   * @param {object} options Дополнительные опции
   * @returns {Promise<object>} Ответ супер-агента
   */
  async query(query, options = {}) {
    const { 
      userId = this.defaultUserId, 
      sessionId = this.sessionId,
      language = 'русский',
      bypassCache = false
    } = options;
    
    try {
      const response = await fetch(`${this.baseUrl}/agent`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          query,
          userId,
          sessionId,
          language,
          bypassCache
        })
      });
      
      if (!response.ok) {
        throw new Error(`Error: ${response.status} ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('Super Agent API error:', error);
      throw error;
    }
  }
  
  /**
   * Выполняет веб-поиск через супер-агента
   * @param {string} query Поисковый запрос
   * @param {object} options Дополнительные опции
   * @returns {Promise<object>} Результаты поиска
   */
  async webSearch(query, options = {}) {
    const { 
      userId = this.defaultUserId, 
      sessionId = this.sessionId,
      language = 'русский',
      bypassCache = false
    } = options;
    
    try {
      const response = await fetch(`${this.baseUrl}/web-search`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          query,
          userId,
          sessionId,
          language,
          bypassCache
        })
      });
      
      if (!response.ok) {
        throw new Error(`Error: ${response.status} ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('Web Search API error:', error);
      throw error;
    }
  }
  
  /**
   * Выполняет задачу с использованием ReAct подхода
   * @param {string} query Запрос пользователя
   * @param {object} options Дополнительные опции
   * @returns {Promise<object>} Результаты выполнения ReAct
   */
  async react(query, options = {}) {
    const { 
      userId = this.defaultUserId, 
      sessionId = this.sessionId,
      language = 'русский',
      reactState = null,
      waitForCompletion = false,
      maxSteps = 10,
      timeout = 30000
    } = options;
    
    try {
      // Первый запрос
      let response = await fetch(`${this.baseUrl}/react`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          query,
          userId,
          sessionId,
          language,
          reactState
        })
      });
      
      if (!response.ok) {
        throw new Error(`Error: ${response.status} ${response.statusText}`);
      }
      
      let result = await response.json();
      
      // Если не нужно ждать завершения, возвращаем сразу
      if (!waitForCompletion) {
        return result;
      }
      
      // Ждем завершения, если задан флаг waitForCompletion
      let steps = 0;
      const startTime = Date.now();
      
      while (!result.finished && steps < maxSteps && (Date.now() - startTime) < timeout) {
        // Пауза между запросами
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Запрашиваем следующий шаг
        response = await fetch(`${this.baseUrl}/react`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            query,
            userId,
            sessionId,
            language,
            reactState: result.reactState
          })
        });
        
        if (!response.ok) {
          throw new Error(`Error: ${response.status} ${response.statusText}`);
        }
        
        result = await response.json();
        steps++;
      }
      
      return result;
    } catch (error) {
      console.error('ReAct API error:', error);
      throw error;
    }
  }
  
  /**
   * Создает новую сессию
   * @param {string} userId ID пользователя
   * @param {object} metadata Метаданные сессии
   * @returns {Promise<object>} Информация о созданной сессии
   */
  async createSession(userId = this.defaultUserId, metadata = {}) {
    try {
      const response = await fetch(`${this.baseUrl}/session/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId,
          metadata
        })
      });
      
      if (!response.ok) {
        throw new Error(`Error: ${response.status} ${response.statusText}`);
      }
      
      const session = await response.json();
      this.sessionId = session.sessionId;
      
      return session;
    } catch (error) {
      console.error('Create Session API error:', error);
      throw error;
    }
  }
}

module.exports = SuperAgentAPI;
