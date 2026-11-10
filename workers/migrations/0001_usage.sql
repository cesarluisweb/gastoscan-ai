CREATE TABLE IF NOT EXISTS usage (
  day TEXT NOT NULL,
  scope TEXT NOT NULL,   -- 'uid:<uid>' o 'global'
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, scope)
);
