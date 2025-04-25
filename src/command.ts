import * as clc from "colorette";
import { Command as CommanderStatic } from "commander";
import { first, last } from "lodash";

import { detectProjectRoot } from "./detectProjectRoot";
import { getInheritedOption, setupLoggers } from "./utils";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type ActionFunction = (...args: any[]) => any;

interface BeforeFunction {
  fn: ActionFunction;
  args: any[];
}

interface CLIClient {
  cli: CommanderStatic;
  errorOut: (e: Error) => void;
}

/**
 * Command is a wrapper around commander to simplify our use of promise-based
 * actions and pre-action hooks.
 */
export class Command {
  private name = "";
  private descriptionText = "";
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private options: any[][] = [];
  private aliases: string[] = [];
  private actionFn: ActionFunction = (): void => {
    // noop by default, unless overwritten by `.action(fn)`.
  };
  private befores: BeforeFunction[] = [];
  private helpText = "";
  private client?: CLIClient;
  private positionalArgs: { name: string; required: boolean }[] = [];

  /**
   * @param cmd the command to create.
   */
  constructor(private cmd: string) {
    this.name = first(cmd.split(" ")) || "";
  }

  /**
   * Sets the description of the command.
   * @param t a human readable description.
   * @return the command, for chaining.
   */
  description(t: string): Command {
    this.descriptionText = t;
    return this;
  }

  /**
   * Sets an alias for a command.
   * @param aliases an alternativre name for the command. Users will be able to call the command via this name.
   * @return the command, for chaining.
   */
  alias(alias: string): Command {
    this.aliases.push(alias);
    return this;
  }

  /**
   * Sets any options for the command.
   *
   * @example
   *   command.option("-d, --debug", "turn on debugging", false)
   *
   * @param args the commander-style option definition.
   * @return the command, for chaining.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  option(...args: any[]): Command {
    this.options.push(args);
    return this;
  }

  /**
   * Sets up --force flag for the command.
   *
   * @param message overrides the description for --force for this command
   * @returns the command, for chaining
   */
  withForce(message?: string): Command {
    this.options.push(["-f, --force", message || "automatically accept all interactive prompts"]);
    return this;
  }

  /**
   * Attaches a function to run before the command's action function.
   * @param fn the function to run.
   * @param args arguments, as an array, for the function.
   * @return the command, for chaining.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  before(fn: ActionFunction, ...args: any[]): Command {
    this.befores.push({ fn: fn, args: args });
    return this;
  }

  /**
   * Sets the help text for the command.
   *
   * This text is displayed when:
   *   - the `--help` flag is passed to the command, or
   *   - the `help <command>` command is used.
   *
   * @param t the human-readable help text.
   * @return the command, for chaining.
   */
  help(t: string): Command {
    this.helpText = t;
    return this;
  }

  /**
   * Sets the function to be run for the command.
   * @param fn the function to be run.
   * @return the command, for chaining.
   */
  action(fn: ActionFunction): Command {
    this.actionFn = fn;
    return this;
  }

  /**
   * Registers the command with the client. This is used to initially set up
   * all the commands and wraps their functionality with analytics and error
   * handling.
   * @param client the client object (from src/index.js).
   */
  register(client: CLIClient): void {
    this.client = client;
    const program = client.cli;
    const cmd = program.command(this.cmd);
    if (this.descriptionText) {
      cmd.description(this.descriptionText);
    }
    if (this.aliases) {
      cmd.aliases(this.aliases);
    }
    this.options.forEach((args) => {
      const flags = args.shift();
      cmd.option(flags, ...args);
    });

    if (this.helpText) {
      cmd.on("--help", () => {
        console.log(); // Seperates the help text from global options.
        console.log(this.helpText);
      });
    }

    // args is an array of all the arguments provided for the command PLUS the
    // options object as provided by Commander (on the end).
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    cmd.action(this.actionFn);
  }

  /**
   * Extends the options with various properties for use in commands.
   * @param options the command options object.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  public async prepare(options: any): Promise<void> {
    options = options || {};
    options.project = getInheritedOption(options, "project");

    if (!process.stdin.isTTY || getInheritedOption(options, "nonInteractive")) {
      options.nonInteractive = true;
    }
    // allow override of detected non-interactive with --interactive flag
    if (getInheritedOption(options, "interactive")) {
      options.interactive = true;
      options.nonInteractive = false;
    }

    if (getInheritedOption(options, "debug")) {
      options.debug = true;
    }

    if (getInheritedOption(options, "json")) {
      options.nonInteractive = true;
    } else {
      setupLoggers();
    }

    if (getInheritedOption(options, "config")) {
      options.configPath = getInheritedOption(options, "config");
    }

    const account = getInheritedOption(options, "account");
    options.account = account;

    // selectAccount needs the projectRoot to be set.
    options.projectRoot = detectProjectRoot(options);
  }

  runner(): (...a: any[]) => Promise<any> {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return async (...args: any[]) => {
      // Make sure the last argument is an object for options, add {} if none
      if (typeof last(args) !== "object" || last(args) === null) {
        args.push({});
      }

      // Args should have one entry for each positional arg (even the optional
      // ones) and end with options.
      while (args.length < this.positionalArgs.length + 1) {
        // Add "" for missing args while keeping options at the end
        args.splice(args.length - 1, 0, "");
      }

      return this.actionFn(...args);
    };
  }
}
