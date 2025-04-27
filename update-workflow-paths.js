const fs = require('fs');
const path = require('path');

const templatesDir = path.join(__dirname, 'workflows', 'templates');
const files = fs.readdirSync(templatesDir);

files.forEach(file => {
  if (file.endsWith('.json')) {
    const filePath = path.join(templatesDir, file);
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Обновляем относительные пути на абсолютные
    content = content.replace(/require\('\.\.\/lib\//g, "require('/home/node/.n8n/lib/");
    
    // Обновляем локализацию для веб-поиска
    if (file === 'web-search.json') {
      const localeCode = `// Маппинг языков на локали
const languageToLocale = {
  'русский': 'ru-ru',
  'английский': 'en-us',
  'испанский': 'es-es',
  'французский': 'fr-fr',
  'немецкий': 'de-de'
};

const locale = languageToLocale[$input.language] || 'ru-ru';

const searchResults = await search(query, {
  safeSearch: 'moderate',
  locale: locale,
  time: 'y' // За последний год
});`;
      
      content = content.replace(/const searchResults = await search\(query, \{[\s\S]*?time: 'y'[\s\S]*?\}\);/, localeCode);
    }
    
    fs.writeFileSync(filePath, content);
    console.log(`Обновлен файл: ${file}`);
  }
});
