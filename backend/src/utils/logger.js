const LOG_LEVELS = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3,
};

const currentLevel = LOG_LEVELS[process.env.LOG_LEVEL] || LOG_LEVELS.INFO;

function formatTimestamp() {
  return new Date().toISOString();
}

const logger = {
  error: (...args) => {
    if (currentLevel >= LOG_LEVELS.ERROR) {
      console.error(`[${formatTimestamp()}] [ERROR]`, ...args);
    }
  },
  warn: (...args) => {
    if (currentLevel >= LOG_LEVELS.WARN) {
      console.warn(`[${formatTimestamp()}] [WARN]`, ...args);
    }
  },
  info: (...args) => {
    if (currentLevel >= LOG_LEVELS.INFO) {
      console.info(`[${formatTimestamp()}] [INFO]`, ...args);
    }
  },
  debug: (...args) => {
    if (currentLevel >= LOG_LEVELS.DEBUG) {
      console.debug(`[${formatTimestamp()}] [DEBUG]`, ...args);
    }
  },
};

module.exports = logger;
