import { IgniteError } from "./error";
import { logError } from "./logError";

/**
 * Errors out by calling `process.exit` with an exit code of 2.
 * @param error an Error to be logged.
 */
export function errorOut(error: Error): void {
  let fbError: IgniteError;
  if (error instanceof IgniteError) {
    fbError = error;
  } else {
    fbError = new IgniteError("An unexpected error has occurred.", {
      original: error,
      exit: 2,
    });
  }

  logError(fbError);
  process.exitCode = fbError.exit || 2;
  setTimeout(() => {
    process.exit();
  }, 250);
}
