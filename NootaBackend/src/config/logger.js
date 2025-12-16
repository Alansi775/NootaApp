import pino from 'pino';

let logger;

export function initializeLogger() {
  if (!logger) {
    const logLevel = process.env.LOG_LEVEL || 'info';
    
    const transport = process.env.NODE_ENV === 'development' 
      ? {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'SYS:standard',
            ignore: 'pid,hostname'
          }
        }
      : undefined;

    logger = pino(
      {
        level: logLevel,
        transport: transport
      }
    );
  }

  return logger;
}

export function getLogger() {
  return logger || initializeLogger();
}
