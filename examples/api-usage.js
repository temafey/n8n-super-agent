/**
 * Пример использования API супер-агента
 */
const SuperAgentAPI = require('../lib/super-agent-api');

async function main() {
  try {
    // Создаем клиент API
    const api = new SuperAgentAPI({
      baseUrl: 'http://localhost:5678/webhook',
      userId: 'user123'
    });
    
    // Создаем новую сессию
    const session = await api.createSession('user123', {
      name: 'Тестовая сессия',
      description: 'Пример использования API супер-агента'
    });
    
    console.log('Создана новая сессия:', session);
    
    // Отправляем запрос супер-агенту
    const queryResult = await api.query('Какая погода сегодня в Москве?', {
      sessionId: session.sessionId,
      language: 'русский'
    });
    
    console.log('Ответ супер-агента:', queryResult);
    
    // Выполняем веб-поиск
    const searchResult = await api.webSearch('Новости технологий', {
      sessionId: session.sessionId
    });
    
    console.log('Результаты поиска:', searchResult);
    
    // Выполняем задачу с использованием ReAct подхода
    const reactResult = await api.react('Рассчитай среднюю цену акций Tesla за последний месяц', {
      sessionId: session.sessionId,
      waitForCompletion: true,
      maxSteps: 5
    });
    
    console.log('Результаты ReAct:', reactResult);
    
  } catch (error) {
    console.error('Ошибка:', error);
  }
}

// Запускаем пример
main();
