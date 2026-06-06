const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };

function ts() {
  return new Date().toISOString();
}

function makeLogger(level) {
  const threshold = LEVELS[level] ?? LEVELS.info;
  function emit(lvl, ...args) {
    if ((LEVELS[lvl] ?? 99) > threshold) return;
    const tag = `[${ts()}] [${lvl.toUpperCase()}]`;
    if (lvl === 'error') console.error(tag, ...args);
    else console.log(tag, ...args);
  }
  return {
    error: (...a) => emit('error', ...a),
    warn:  (...a) => emit('warn', ...a),
    info:  (...a) => emit('info', ...a),
    debug: (...a) => emit('debug', ...a),
  };
}

import { config } from './config.js';
export const log = makeLogger(config.logLevel);
