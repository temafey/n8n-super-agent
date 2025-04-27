const fetch = require('node-fetch');

/**
 * Отслеживает использование токенов и затраты на API
 */
class TokenMonitor {
  constructor(dbClient) {
    this.dbClient = dbClient;
    
    // Стоимость токенов (обновите в соответствии с актуальными ценами)
    this.pricing = {
      'gpt-3.5-turbo': { input: 0.0000015, output: 0.000002 },
      'gpt-4': { input: 0.00003, output: 0.00006 },
      'gpt-4-32k': { input: 0.00006, output: 0.00012 },
      'local-llm': { input: 0, output: 0 }
    };
  }
  
  /**
   * Записывает использование токенов
   * @param {string} userId ID пользователя
   * @param {string} model Используемая модель
   * @param {number} inputTokens Количество входных токенов
   * @param {number} outputTokens Количество выходных токенов
   * @param {string} requestType Тип запроса
   * @returns {object} Данные об использовании
   */
  async trackTokenUsage(userId, model, inputTokens, outputTokens, requestType = 'text-completion') {
    // Используем цены по умолчанию, если модель не найдена
    const price = this.pricing[model] || this.pricing['gpt-3.5-turbo'];
    
    // Вычисляем стоимость
    const inputCost = inputTokens * price.input;
    const outputCost = outputTokens * price.output;
    const totalCost = inputCost + outputCost;
    
    // Данные для записи
    const usageData = {
      userId,
      model,
      inputTokens,
      outputTokens,
      totalTokens: inputTokens + outputTokens,
      inputCost,
      outputCost,
      totalCost,
      requestType,
      timestamp: new Date().toISOString()
    };
    
    // Записываем использование в базу данных (если доступна)
    if (this.dbClient) {
      try {
        // Пример запроса к PostgreSQL
        await this.dbClient.query(`
          INSERT INTO token_usage 
          (user_id, model, input_tokens, output_tokens, total_tokens, 
          input_cost, output_cost, total_cost, request_type, timestamp)
          VALUES 
          ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        `, [
          usageData.userId,
          usageData.model,
          usageData.inputTokens,
          usageData.outputTokens,
          usageData.totalTokens,
          usageData.inputCost,
          usageData.outputCost,
          usageData.totalCost,
          usageData.requestType,
          usageData.timestamp
        ]);
      } catch (error) {
        console.error(`Failed to record token usage: ${error.message}`);
      }
    }
    
    return usageData;
  }
  
  /**
   * Проверяет квоты пользователя
   * @param {string} userId ID пользователя
   * @returns {object} Информация о квотах и использовании
   */
  async checkUserQuota(userId) {
    try {
      // Получаем квоту пользователя из базы данных
      let quota = {
        daily_token_limit: 10000,
        monthly_cost_limit: 10.0,
        quota_type: 'soft'
      };
      
      // Получаем текущее использование
      const today = new Date().toISOString().split('T')[0];
      const currentMonth = new Date().getMonth() + 1;
      const currentYear = new Date().getFullYear();
      
      let dailyTokens = 0;
      let monthlyCost = 0;
      
      if (this.dbClient) {
        // Получаем дневное использование токенов
        const dailyResult = await this.dbClient.query(`
          SELECT SUM(total_tokens) as daily_tokens
          FROM token_usage
          WHERE user_id = $1
          AND DATE(timestamp) = $2
        `, [userId, today]);
        
        if (dailyResult.rows.length > 0 && dailyResult.rows[0].daily_tokens) {
          dailyTokens = parseInt(dailyResult.rows[0].daily_tokens);
        }
        
        // Получаем месячные затраты
        const monthlyResult = await this.dbClient.query(`
          SELECT SUM(total_cost) as monthly_cost
          FROM token_usage
          WHERE user_id = $1
          AND EXTRACT(MONTH FROM timestamp) = $2
          AND EXTRACT(YEAR FROM timestamp) = $3
        `, [userId, currentMonth, currentYear]);
        
        if (monthlyResult.rows.length > 0 && monthlyResult.rows[0].monthly_cost) {
          monthlyCost = parseFloat(monthlyResult.rows[0].monthly_cost);
        }
        
        // Получаем квоты пользователя, если они установлены
        const quotaResult = await this.dbClient.query(`
          SELECT * FROM user_quotas WHERE user_id = $1
        `, [userId]);
        
        if (quotaResult.rows.length > 0) {
          quota = quotaResult.rows[0];
        } else {
          // Создаем запись с квотами по умолчанию
          await this.dbClient.query(`
            INSERT INTO user_quotas 
            (user_id, daily_token_limit, monthly_cost_limit, reset_day, quota_type)
            VALUES ($1, $2, $3, $4, $5)
          `, [userId, quota.daily_token_limit, quota.monthly_cost_limit, 1, quota.quota_type]);
        }
      }
      
      // Вычисляем остатки
      const dailyTokensRemaining = quota.daily_token_limit - dailyTokens;
      const monthlyCostRemaining = quota.monthly_cost_limit - monthlyCost;
      
      // Определяем статус квоты
      const isHardQuota = quota.quota_type === 'hard';
      const dailyLimitExceeded = dailyTokensRemaining <= 0;
      const monthlyLimitExceeded = monthlyCostRemaining <= 0;
      
      return {
        user_id: userId,
        quota,
        usage: {
          daily_tokens: dailyTokens,
          monthly_cost: monthlyCost
        },
        remaining: {
          daily_tokens: dailyTokensRemaining,
          monthly_cost: monthlyCostRemaining
        },
        status: {
          daily_limit_exceeded: dailyLimitExceeded,
          monthly_limit_exceeded: monthlyLimitExceeded,
          can_proceed: !(isHardQuota && (dailyLimitExceeded || monthlyLimitExceeded))
        }
      };
    } catch (error) {
      console.error(`Failed to check user quota: ${error.message}`);
      // В случае ошибки возвращаем разрешение на продолжение
      return {
        user_id: userId,
        status: {
          can_proceed: true,
          error: error.message
        }
      };
    }
  }
  
  /**
   * Генерирует отчет об использовании токенов
   * @param {string} period Период отчета ('day', 'week', 'month')
   * @returns {object} Отчет об использовании
   */
  async generateUsageReport(period = 'day') {
    try {
      if (!this.dbClient) {
        throw new Error('Database client not available');
      }
      
      let timeFilter;
      switch (period) {
        case 'week':
          timeFilter = "timestamp > NOW() - INTERVAL '7 DAYS'";
          break;
        case 'month':
          timeFilter = "timestamp > NOW() - INTERVAL '30 DAYS'";
          break;
        case 'day':
        default:
          timeFilter = "timestamp > NOW() - INTERVAL '24 HOURS'";
          break;
      }
      
      // Отчет по пользователям
      const userResult = await this.dbClient.query(`
        SELECT user_id, SUM(total_tokens) as tokens, SUM(total_cost) as cost 
        FROM token_usage 
        WHERE ${timeFilter}
        GROUP BY user_id 
        ORDER BY cost DESC
      `);
      
      // Отчет по моделям
      const modelResult = await this.dbClient.query(`
        SELECT model, SUM(total_tokens) as tokens, SUM(total_cost) as cost 
        FROM token_usage 
        WHERE ${timeFilter}
        GROUP BY model 
        ORDER BY cost DESC
      `);
      
      // Отчет по типам запросов
      const typeResult = await this.dbClient.query(`
        SELECT request_type, SUM(total_tokens) as tokens, SUM(total_cost) as cost 
        FROM token_usage 
        WHERE ${timeFilter}
        GROUP BY request_type 
        ORDER BY cost DESC
      `);
      
      return {
        period,
        userUsage: userResult.rows,
        modelUsage: modelResult.rows,
        typeUsage: typeResult.rows,
        totals: {
          tokens: userResult.rows.reduce((sum, row) => sum + parseInt(row.tokens), 0),
          cost: userResult.rows.reduce((sum, row) => sum + parseFloat(row.cost), 0)
        }
      };
    } catch (error) {
      console.error(`Failed to generate usage report: ${error.message}`);
      return { error: error.message };
    }
  }
}

module.exports = TokenMonitor;
