/**
 * Пример использования мониторинга токенов
 */
const TokenMonitor = require('../lib/token-monitor');

// Создаем имитацию клиента базы данных
const mockDbClient = {
  query: async (sql, params) => {
    console.log('SQL запрос:', sql);
    console.log('Параметры:', params);
    
    // Имитируем различные ответы на запросы
    if (sql.includes('user_quotas')) {
      return { 
        rows: [{
          user_id: params[0],
          daily_token_limit: 10000,
          monthly_cost_limit: 10.0,
          reset_day: 1,
          quota_type: 'soft'
        }] 
      };
    } else if (sql.includes('daily_tokens')) {
      return { rows: [{ daily_tokens: 5000 }] };
    } else if (sql.includes('monthly_cost')) {
      return { rows: [{ monthly_cost: 3.75 }] };
    } else {
      return { rows: [] };
    }
  }
};

// Создаем экземпляр TokenMonitor
const tokenMonitor = new TokenMonitor(mockDbClient);

// Функция для демонстрации трекинга использования токенов
async function trackUsageDemo() {
  console.log('\n=== ТРЕКИНГ ИСПОЛЬЗОВАНИЯ ТОКЕНОВ ===');
  
  const usageData = [
    { userId: 'user1', model: 'gpt-3.5-turbo', inputTokens: 500, outputTokens: 300, requestType: 'chat' },
    { userId: 'user2', model: 'gpt-4', inputTokens: 1000, outputTokens: 800, requestType: 'completion' },
    { userId: 'user1', model: 'local-llm', inputTokens: 800, outputTokens: 400, requestType: 'chat' }
  ];
  
  for (const data of usageData) {
    const result = await tokenMonitor.trackTokenUsage(
      data.userId,
      data.model,
      data.inputTokens,
      data.outputTokens,
      data.requestType
    );
    
    console.log(`\nЗаписано использование для ${data.userId}:`);
    console.log(`  Модель: ${data.model}`);
    console.log(`  Токены: ${data.inputTokens} вход, ${data.outputTokens} выход`);
    console.log(`  Стоимость: $${result.totalCost.toFixed(6)}`);
  }
}

// Функция для демонстрации проверки квот
async function checkQuotaDemo() {
  console.log('\n=== ПРОВЕРКА КВОТ ПОЛЬЗОВАТЕЛЕЙ ===');
  
  const userIds = ['user1', 'user2', 'user3'];
  
  for (const userId of userIds) {
    const quota = await tokenMonitor.checkUserQuota(userId);
    
    console.log(`\nКвота для ${userId}:`);
    console.log(`  Дневной лимит: ${quota.quota.daily_token_limit} токенов`);
    console.log(`  Месячный лимит: $${quota.quota.monthly_cost_limit}`);
    console.log(`  Текущее использование: ${quota.usage.daily_tokens} токенов, $${quota.usage.monthly_cost}`);
    console.log(`  Остаток: ${quota.remaining.daily_tokens} токенов, $${quota.remaining.monthly_cost.toFixed(2)}`);
    console.log(`  Статус: ${quota.status.can_proceed ? 'Можно продолжать' : 'Лимит превышен'}`);
  }
}

// Функция для демонстрации генерации отчетов
async function generateReportDemo() {
  console.log('\n=== ГЕНЕРАЦИЯ ОТЧЕТОВ ОБ ИСПОЛЬЗОВАНИИ ===');
  
  // Имитируем результаты запросов для генерации отчетов
  mockDbClient.query = async (sql) => {
    if (sql.includes('user_id')) {
      return {
        rows: [
          { user_id: 'user1', tokens: 12500, cost: 0.45 },
          { user_id: 'user2', tokens: 32000, cost: 2.80 },
          { user_id: 'user3', tokens: 5000, cost: 0.12 }
        ]
      };
    } else if (sql.includes('model')) {
      return {
        rows: [
          { model: 'gpt-4', tokens: 30000, cost: 2.70 },
          { model: 'gpt-3.5-turbo', tokens: 18000, cost: 0.62 },
          { model: 'local-llm', tokens: 1500, cost: 0.05 }
        ]
      };
    } else if (sql.includes('request_type')) {
      return {
        rows: [
          { request_type: 'chat', tokens: 25000, cost: 1.80 },
          { request_type: 'completion', tokens: 20000, cost: 1.40 },
          { request_type: 'embedding', tokens: 4500, cost: 0.17 }
        ]
      };
    }
  };
  
  for (const period of ['day', 'week', 'month']) {
    const report = await tokenMonitor.generateUsageReport(period);
    
    console.log(`\nОтчет за ${period}:`);
    console.log('  Использование по пользователям:');
    report.userUsage.forEach(user => {
      console.log(`    ${user.user_id}: ${user.tokens} токенов, $${user.cost}`);
    });
    
    console.log('  Использование по моделям:');
    report.modelUsage.forEach(model => {
      console.log(`    ${model.model}: ${model.tokens} токенов, $${model.cost}`);
    });
    
    console.log('  Использование по типам запросов:');
    report.typeUsage.forEach(type => {
      console.log(`    ${type.request_type}: ${type.tokens} токенов, $${type.cost}`);
    });
    
    console.log(`  Всего: ${report.totals.tokens} токенов, $${report.totals.cost}`);
  }
}

// Запускаем демонстрации
async function main() {
  try {
    await trackUsageDemo();
    await checkQuotaDemo();
    await generateReportDemo();
  } catch (error) {
    console.error('Ошибка:', error);
  }
}

main();
