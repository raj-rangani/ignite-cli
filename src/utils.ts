import * as winston from "winston";
import { logger } from ".";
import { stripVTControlCharacters } from "node:util";

export function getInheritedOption(options: any, key: string): any {
  let target = options;
  while (target) {
    if (target[key] !== undefined) {
      return target[key];
    }
    target = target.parent;
  }
}

export function tryStringify(value: any) {
  if (typeof value === "string") {
    return value;
  }

  try {
    return JSON.stringify(value);
  } catch {
    return value;
  }
}

export function setupLoggers() {
  if (process.env.DEBUG) {
    logger.add(
      new winston.transports.Console({
        level: "debug",
        format: winston.format.printf((info) => {
          const segments = [info.message].map(tryStringify);
          return `${stripVTControlCharacters(segments.join(" "))}`;
        }),
      })
    );
  } else if (process.env.IS_FIREBASE_CLI) {
    logger.add(
      new winston.transports.Console({
        level: "info",
        format: winston.format.printf((info) =>
          [info.message].filter((chunk) => typeof chunk === "string").join(" ")
        ),
      })
    );
  }
}
