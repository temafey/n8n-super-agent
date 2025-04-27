/**
 * Пример использования Weaviate
 */
const WeaviateClient = require('../lib/weaviate-client');
const { initializeWeaviateSchema } = require('../lib/weaviate-schema');

// Функция для инициализации схемы Weaviate
async function initializeSchema() {
  try {
    console.log('Инициализация схемы Weaviate...');
    const result = await initializeWeaviateSchema();
    console.log('Результат инициализации:', result);
  } catch (error) {
    console.error('Ошибка инициализации схемы:', error);
  }
}

// Функция для добавления примеров данных
async function addSampleData() {
  try {
    console.log('\n=== ДОБАВЛЕНИЕ ТЕСТОВЫХ ДАННЫХ ===');
    
    const weaviate = new WeaviateClient();
    
    // Примеры данных
    const sampleData = [
      {
        content: 'Машинное обучение (ML) — это подраздел искусственного интеллекта, изучающий методы построения алгоритмов, способных обучаться на данных.',
        category: 'Technology',
        source: 'Wikipedia',
        userId: 'user1'
      },
      {
        content: 'Python — высокоуровневый язык программирования общего назначения с акцентом на читаемость кода.',
        category: 'Programming',
        source: 'Documentation',
        userId: 'user1'
      },
      {
        content: 'Нейронные сети — это вычислительные системы, вдохновленные биологическими нейронными сетями, которые составляют мозг животных.',
        category: 'Technology',
        source: 'Article',
        userId: 'user2'
      },
      {
        content: 'JavaScript — это язык программирования, который следует спецификации ECMAScript. JavaScript является прототипно-ориентированным, мультипарадигменным языком.',
        category: 'Programming',
        source: 'Book',
        userId: 'user2'
      },
      {
        content: 'Глубокое обучение (Deep Learning) — это подраздел машинного обучения, основанный на искусственных нейронных сетях с большим количеством слоев.',
        category: 'Technology',
        source: 'Research',
        userId: 'user3'
      }
    ];
    
    // Добавление всех образцов в Weaviate
    for (const sample of sampleData) {
      const properties = {
        content: sample.content,
        category: sample.category,
        source: sample.source,
        timestamp: new Date().toISOString(),
        userId: sample.userId
      };
      
      const result = await weaviate.addObject('AgentMemory', properties);
      console.log(`Добавлен объект: ${result.id}`);
      console.log(`  Содержание: ${sample.content.substring(0, 50)}...`);
      console.log(`  Категория: ${sample.category}`);
      console.log(`  Источник: ${sample.source}`);
      console.log('');
    }
    
    console.log('Все тестовые данные успешно добавлены!');
  } catch (error) {
    console.error('Ошибка добавления данных:', error);
  }
}

// Функция для тестирования поиска
async function testSearch() {
  try {
    console.log('\n=== ТЕСТИРОВАНИЕ ПОИСКА ===');
    
    const weaviate = new WeaviateClient();
    
    // Тестовые запросы
    const queries = [
      {
        name: 'Семантический поиск',
        text: 'технологии искусственного интеллекта',
        filters: null
      },
      {
        name: 'Поиск с фильтром',
        text: 'язык программирования',
        filters: {
          operator: 'Equal',
          path: ['category'],
          valueString: 'Programming'
        }
      },
      {
        name: 'Поиск по пользователю',
        text: 'обучение',
        filters: {
          operator: 'Equal',
          path: ['userId'],
          valueString: 'user3'
        }
      }
    ];
    
    // Выполнение каждого поискового запроса
    for (const query of queries) {
      console.log(`\n--- ${query.name} ---`);
      console.log(`Запрос: "${query.text}"`);
      
      if (query.filters) {
        console.log('Фильтры:', JSON.stringify(query.filters, null, 2));
      }
      
      const results = await weaviate.keywordSearch('AgentMemory', query.text, 3, query.filters);
      
      console.log(`Найдено результатов: ${results.length}`);
      
      for (let i = 0; i < results.length; i++) {
        const result = results[i];
        const score = result._additional.score || (1 - result._additional.distance);
        
        console.log(`\nРезультат ${i+1} (релевантность: ${score.toFixed(4)}):`);
        console.log(`Содержание: ${result.content.substring(0, 100)}...`);
        console.log(`Категория: ${result.category}`);
        console.log(`Источник: ${result.source}`);
      }
    }
  } catch (error) {
    console.error('Ошибка поиска:', error);
  }
}

// Основная функция
async function main() {
  try {
    // Инициализация схемы
    await initializeSchema();
    
    // Добавление тестовых данных
    await addSampleData();
    
    // Пауза для индексации данных
    console.log('\nОжидание индексации данных в Weaviate (5 секунд)...');
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Тестирование поиска
    await testSearch();
    
  } catch (error) {
    console.error('Ошибка выполнения сценария:', error);
  }
}

// Запускаем основную функцию
main();
