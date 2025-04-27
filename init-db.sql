-- Таблица для отслеживания использования токенов
CREATE TABLE IF NOT EXISTS token_usage (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  user_id VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  input_tokens INTEGER NOT NULL,
  output_tokens INTEGER NOT NULL,
  total_tokens INTEGER NOT NULL,
  input_cost DECIMAL(10, 6) NOT NULL,
  output_cost DECIMAL(10, 6) NOT NULL,
  total_cost DECIMAL(10, 6) NOT NULL,
  request_type VARCHAR(255) NOT NULL
);

-- Таблица для квот пользователей
CREATE TABLE IF NOT EXISTS user_quotas (
  user_id VARCHAR(255) PRIMARY KEY,
  daily_token_limit INTEGER NOT NULL DEFAULT 10000,
  monthly_cost_limit DECIMAL(10, 2) NOT NULL DEFAULT 10.00,
  reset_day INTEGER NOT NULL DEFAULT 1,
  quota_type VARCHAR(50) NOT NULL DEFAULT 'soft' -- 'soft' or 'hard'
);

-- Индексы для оптимизации запросов
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_timestamp ON token_usage(timestamp);
CREATE INDEX IF NOT EXISTS idx_token_usage_model ON token_usage(model);
CREATE INDEX IF NOT EXISTS idx_token_usage_request_type ON token_usage(request_type);

-- Таблица для хранения сессий и сеансов разговоров
CREATE TABLE IF NOT EXISTS sessions (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL UNIQUE,
  user_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  metadata JSONB
);

-- Таблица для хранения сообщений в сессиях
CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL, -- 'user', 'assistant', 'system'
  content TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  metadata JSONB,
  FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
);

-- Индексы для таблиц сессий и сообщений
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Представление для аналитики использования по дням
CREATE OR REPLACE VIEW daily_usage_stats AS
SELECT 
  DATE(timestamp) as date,
  user_id,
  SUM(total_tokens) as total_tokens,
  SUM(total_cost) as total_cost,
  COUNT(*) as request_count
FROM token_usage
GROUP BY DATE(timestamp), user_id
ORDER BY DATE(timestamp) DESC, total_cost DESC;

-- Представление для аналитики использования по моделям
CREATE OR REPLACE VIEW model_usage_stats AS
SELECT 
  model,
  SUM(total_tokens) as total_tokens,
  SUM(total_cost) as total_cost,
  COUNT(*) as request_count
FROM token_usage
WHERE timestamp > NOW() - INTERVAL '30 DAYS'
GROUP BY model
ORDER BY total_cost DESC;
