/**
 * Утилита для оптимизации промптов
 */
class PromptOptimizer {
  /**
   * Оптимизирует промпт для минимизации использования токенов
   * @param {string} originalPrompt Исходный промпт
   * @param {string} mode Режим оптимизации ('minimal', 'normal', 'detailed')
   * @returns {object} Результат оптимизации
   */
  static optimizePrompt(originalPrompt, mode = 'normal') {
    // Режимы оптимизации:
    // - minimal: максимальное сокращение для экономии токенов
    // - normal: баланс экономии и качества
    // - detailed: акцент на качество с минимальной оптимизацией
    
    let optimizedPrompt = originalPrompt;
    
    // Общие оптимизации для всех режимов
    optimizedPrompt = optimizedPrompt
      .replace(/\n{3,}/g, '\n\n')                          // Убираем лишние переносы строк
      .replace(/([.!?])\s+/g, '$1 ')                       // Оптимизируем пробелы после знаков препинания
      .replace(/\s{2,}/g, ' ');                            // Убираем множественные пробелы
    
    if (mode === 'minimal') {
      // Максимальная оптимизация
      optimizedPrompt = optimizedPrompt
        .replace(/I would like you to|Could you please|Please|I want you to/gi, '')
        .replace(/\b(really|very|extremely|absolutely|definitely)\b/gi, '')
        .replace(/\b(small|minor|brief|tiny)\b/gi, 'small')
        .replace(/\b(large|major|extensive|huge)\b/gi, 'large')
        .replace(/\b(good|great|excellent|fantastic|amazing)\b/gi, 'good')
        .replace(/\b(bad|poor|terrible|awful|horrible)\b/gi, 'bad');
    } else if (mode === 'normal') {
      // Умеренная оптимизация
      optimizedPrompt = optimizedPrompt
        .replace(/I would like you to|Could you please/gi, 'Please')
        .replace(/\b(really|extremely|absolutely)\b/gi, 'very');
    }
    
    // Дополнительная оптимизация для длинных промптов
    if (optimizedPrompt.length > 500) {
      // Разбиваем на части и удаляем избыточные инструкции
      const parts = optimizedPrompt.split('\n\n');
      const keyParts = parts.filter((part, index) => {
        // Оставляем первую часть (обычно роль) и последнюю (обычно запрос)
        if (index === 0 || index === parts.length - 1) return true;
        
        // Фильтруем повторы и общие инструкции
        return !part.match(/as (an|a) AI|helpful assistant|respond in a|be concise|be detailed/i);
      });
      
      optimizedPrompt = keyParts.join('\n\n');
    }
    
    return {
      original: originalPrompt,
      optimized: optimizedPrompt,
      original_length: originalPrompt.length,
      optimized_length: optimizedPrompt.length,
      reduction_percent: Math.round((1 - optimizedPrompt.length / originalPrompt.length) * 100)
    };
  }
  
  /**
   * Выбирает подходящую модель на основе сложности запроса
   * @param {string} query Запрос пользователя
   * @param {string} context Контекст (предыдущие сообщения, память и т.д.)
   * @param {object} options Дополнительные параметры
   * @returns {object} Рекомендации по выбору модели
   */
  static selectModelByComplexity(query, context = '', options = {}) {
    // Оценка сложности запроса
    const queryComplexity = this.assessQueryComplexity(query);
    
    // Оценка важности контекста
    const contextImportance = this.assessContextImportance(context);
    
    // Оценка требуемой точности (из опций)
    const requiredAccuracy = options.accuracy || 'normal';
    
    // Матрица выбора моделей
    const modelMatrix = {
      low: {
        low: {
          low: 'local-small',      // Низкая сложность, малоценный контекст, низкая точность
          normal: 'local-medium',  // Низкая сложность, малоценный контекст, средняя точность
          high: 'gpt-3.5-turbo'    // Низкая сложность, малоценный контекст, высокая точность
        },
        normal: {
          low: 'local-medium',     // Низкая сложность, средний контекст, низкая точность
          normal: 'gpt-3.5-turbo', // Низкая сложность, средний контекст, средняя точность
          high: 'gpt-3.5-turbo'    // Низкая сложность, средний контекст, высокая точность
        },
        high: {
          low: 'gpt-3.5-turbo',    // Низкая сложность, ценный контекст, низкая точность
          normal: 'gpt-3.5-turbo', // Низкая сложность, ценный контекст, средняя точность
          high: 'gpt-4'            // Низкая сложность, ценный контекст, высокая точность
        }
      },
      normal: {
        low: {
          low: 'local-medium',     // Средняя сложность, малоценный контекст, низкая точность
          normal: 'gpt-3.5-turbo', // Средняя сложность, малоценный контекст, средняя точность
          high: 'gpt-3.5-turbo'    // Средняя сложность, малоценный контекст, высокая точность
        },
        normal: {
          low: 'gpt-3.5-turbo',    // Средняя сложность, средний контекст, низкая точность
          normal: 'gpt-3.5-turbo', // Средняя сложность, средний контекст, средняя точность
          high: 'gpt-4'            // Средняя сложность, средний контекст, высокая точность
        },
        high: {
          low: 'gpt-3.5-turbo',    // Средняя сложность, ценный контекст, низкая точность
          normal: 'gpt-4',         // Средняя сложность, ценный контекст, средняя точность
          high: 'gpt-4'            // Средняя сложность, ценный контекст, высокая точность
        }
      },
      high: {
        low: {
          low: 'gpt-3.5-turbo',    // Высокая сложность, малоценный контекст, низкая точность
          normal: 'gpt-3.5-turbo', // Высокая сложность, малоценный контекст, средняя точность
          high: 'gpt-4'            // Высокая сложность, малоценный контекст, высокая точность
        },
        normal: {
          low: 'gpt-3.5-turbo',    // Высокая сложность, средний контекст, низкая точность
          normal: 'gpt-4',         // Высокая сложность, средний контекст, средняя точность
          high: 'gpt-4'            // Высокая сложность, средний контекст, высокая точность
        },
        high: {
          low: 'gpt-4',            // Высокая сложность, ценный контекст, низкая точность
          normal: 'gpt-4',         // Высокая сложность, ценный контекст, средняя точность
          high: 'gpt-4'            // Высокая сложность, ценный контекст, высокая точность
        }
      }
    };
    
    // Выбор модели на основе матрицы
    const selectedModel = modelMatrix[queryComplexity][contextImportance][requiredAccuracy];
    
    return {
      query,
      assessments: {
        query_complexity: queryComplexity,
        context_importance: contextImportance,
        required_accuracy: requiredAccuracy
      },
      selected_model: selectedModel
    };
  }
  
  /**
   * Оценивает сложность запроса
   * @param {string} query Запрос пользователя
   * @returns {string} Оценка сложности ('low', 'normal', 'high')
   */
  static assessQueryComplexity(query) {
    // Простая эвристика для оценки сложности запроса
    const complexityFactors = {
      length: query.length > 200 ? 'high' : (query.length > 100 ? 'normal' : 'low'),
      questionWords: /why|how|explain|analyze|compare|difference|evaluate|synthesize/i.test(query) ? 'high' : 'low',
      technicalTerms: /api|code|algorithm|data|technical|implement|architecture/i.test(query) ? 'high' : 'low'
    };
    
    // Подсчет факторов для определения общей сложности
    const counts = {
      low: 0,
      normal: 0,
      high: 0
    };
    
    Object.values(complexityFactors).forEach(level => {
      counts[level]++;
    });
    
    // Определение общей сложности
    if (counts.high > 1) return 'high';
    if (counts.high === 1 || counts.normal > 1) return 'normal';
    return 'low';
  }
  
  /**
   * Оценивает важность контекста
   * @param {string} context Контекст (предыдущие сообщения, память и т.д.)
   * @returns {string} Оценка важности ('low', 'normal', 'high')
   */
  static assessContextImportance(context) {
    // Если контекст отсутствует или очень короткий
    if (!context || context.length < 50) return 'low';
    
    // Если контекст содержит ключевые индикаторы важности
    if (context.match(/important|critical|sensitive|confidential|private/i)) return 'high';
    
    // По умолчанию средняя важность
    return 'normal';
  }
}

module.exports = PromptOptimizer;
