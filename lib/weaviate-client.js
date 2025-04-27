const fetch = require('node-fetch');
const { v4: uuidv4 } = require('uuid');

class WeaviateClient {
  constructor(baseUrl = 'http://weaviate:8080/v1') {
    this.baseUrl = baseUrl;
  }
  
  // Добавление объекта в Weaviate
  async addObject(className, properties, vector = null) {
    try {
      const object = {
        class: className,
        properties,
        id: uuidv4()
      };
      
      // Если вектор предоставлен, используем его
      if (vector) {
        object.vector = vector;
      }
      
      const response = await fetch(`${this.baseUrl}/objects`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(object)
      });
      
      if (!response.ok) {
        throw new Error(`Error adding object: ${await response.text()}`);
      }
      
      const result = await response.json();
      return { id: result.id, ...object };
    } catch (error) {
      console.error(`Failed to add object to Weaviate: ${error.message}`);
      throw error;
    }
  }
  
  // Поиск по векторной близости
  async vectorSearch(className, vector, limit = 5, filters = null) {
    try {
      // Формируем GraphQL запрос
      const whereFilter = filters ? `, where: ${JSON.stringify(filters)}` : '';
      
      const graphqlQuery = {
        query: `
        {
          Get {
            ${className}(
              nearVector: {
                vector: ${JSON.stringify(vector)}
              }
              limit: ${limit}
              ${whereFilter}
            ) {
              _additional {
                id
                distance
              }
              content
              category
              source
              timestamp
            }
          }
        }
        `
      };
      
      const response = await fetch(`${this.baseUrl}/graphql`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(graphqlQuery)
      });
      
      if (!response.ok) {
        throw new Error(`Error searching Weaviate: ${await response.text()}`);
      }
      
      const result = await response.json();
      return (result.data && result.data.Get && result.data.Get[className]) ? result.data.Get[className] : [];
    } catch (error) {
      console.error(`Failed to search Weaviate: ${error.message}`);
      throw error;
    }
  }
  
  // Поиск по ключевым словам
  async keywordSearch(className, text, limit = 5, filters = null) {
    try {
      // Формируем GraphQL запрос с бивекторным поиском
      const whereFilter = filters ? `, where: ${JSON.stringify(filters)}` : '';
      
      const graphqlQuery = {
        query: `
        {
          Get {
            ${className}(
              hybrid: {
                query: "${text.replace(/"/g, '\\"')}"
                alpha: 0.5
              }
              limit: ${limit}
              ${whereFilter}
            ) {
              _additional {
                id
                score
              }
              content
              category
              source
              timestamp
            }
          }
        }
        `
      };
      
      const response = await fetch(`${this.baseUrl}/graphql`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(graphqlQuery)
      });
      
      if (!response.ok) {
        throw new Error(`Error keyword searching Weaviate: ${await response.text()}`);
      }
      
      const result = await response.json();
      return (result.data && result.data.Get && result.data.Get[className]) ? result.data.Get[className] : [];
    } catch (error) {
      console.error(`Failed to keyword search Weaviate: ${error.message}`);
      throw error;
    }
  }
  
  // Удаление объекта
  async deleteObject(id) {
    try {
      const response = await fetch(`${this.baseUrl}/objects/${id}`, {
        method: 'DELETE'
      });
      
      if (!response.ok) {
        throw new Error(`Error deleting object: ${await response.text()}`);
      }
      
      return { success: true, id };
    } catch (error) {
      console.error(`Failed to delete object from Weaviate: ${error.message}`);
      throw error;
    }
  }
}

module.exports = WeaviateClient;
