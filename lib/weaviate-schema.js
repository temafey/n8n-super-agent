const fetch = require('node-fetch');

async function initializeWeaviateSchema() {
  const weaviateUrl = 'http://weaviate:8080/v1';
  
  // Определение класса для хранения данных
  const agentMemoryClass = {
    class: 'AgentMemory',
    description: 'Память супер-агента, включая запросы и ответы',
    vectorizer: 'text2vec-openai',
    moduleConfig: {
      'text2vec-openai': {
        model: 'ada',
        modelVersion: '002',
        type: 'text'
      }
    },
    properties: [
      {
        name: 'content',
        description: 'Основное содержимое (текст запроса или ответа)',
        dataType: ['text']
      },
      {
        name: 'category',
        description: 'Категория контента',
        dataType: ['string']
      },
      {
        name: 'source',
        description: 'Источник данных',
        dataType: ['string']
      },
      {
        name: 'timestamp',
        description: 'Время создания',
        dataType: ['date']
      },
      {
        name: 'userId',
        description: 'Идентификатор пользователя',
        dataType: ['string'],
        indexFilterable: true,
        indexSearchable: true
      }
    ]
  };
  
  // Проверка существования класса
  try {
    const classResponse = await fetch(`${weaviateUrl}/schema/AgentMemory`);
    
    if (classResponse.status === 404) {
      // Создание класса, если он не существует
      const createResponse = await fetch(`${weaviateUrl}/schema`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(agentMemoryClass)
      });
      
      if (!createResponse.ok) {
        throw new Error(`Error creating schema: ${await createResponse.text()}`);
      }
      
      console.log('Weaviate schema created successfully');
      return true;
    } else if (classResponse.ok) {
      console.log('Weaviate schema already exists');
      return true;
    } else {
      throw new Error(`Error checking schema: ${await classResponse.text()}`);
    }
  } catch (error) {
    console.error(`Failed to initialize Weaviate schema: ${error.message}`);
    throw error;
  }
}

module.exports = { initializeWeaviateSchema };
