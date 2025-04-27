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
