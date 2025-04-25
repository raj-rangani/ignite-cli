import { program } from "commander";
import { logger } from "./logger";
import * as clc from "colorette";
import leven from "leven";
// Version information
program.version("1.0.0");

const client = {
  cli: program,
  logger: require("./logger"),
  errorOut: require("./errorOut").errorOut,
  getCommand: (name: string) => {
    for (let i = 0; i < client.cli.commands.length; i++) {
      if (client.cli.commands[i].name() === name) {
        return client.cli.commands[i];
      }
    }
    return;
  },
};

require("./commands").load(client);

/**
 * Checks to see if there is a different command similar to the provided one.
 * This prints the suggestion and returns it if there is one.
 * @param cmd The command as provided by the user.
 * @param cmdList List of commands available in the CLI.
 * @return Returns the suggested command; undefined if none.
 */
function suggestCommands(cmd: string, cmdList: string[]): string | undefined {
  const suggestion = cmdList.find((c) => {
    return leven(c, cmd) < c.length * 0.4;
  });
  if (suggestion) {
    logger.error();
    logger.error("Did you mean " + clc.bold(suggestion) + "?");
    return suggestion;
  }
}

const commandNames = program.commands.map((cmd: any) => {
  return cmd._name;
});

const RENAMED_COMMANDS: Record<string, string> = {};

// Default handler, this is called when no other command action matches.
program.action((_, args) => {
  const cmd = args[0];
  logger.error(clc.bold(clc.red("Error:")), clc.bold(cmd), "is not a Ignite command");

  if (RENAMED_COMMANDS[cmd]) {
    logger.error();
    logger.error(
      clc.bold(cmd) + " has been renamed, please run",
      clc.bold("Ignite " + RENAMED_COMMANDS[cmd]),
      "instead"
    );
  } else {
    // Check if the first argument is close to a command.
    if (!suggestCommands(cmd, commandNames)) {
      // Check to see if combining the two arguments comes close to a command.
      // e.g. `Ignite hosting disable` may suggest `hosting:disable`.
      suggestCommands(args.join(":"), commandNames);
    }
  }

  process.exit(1);
});

// NB: Keep this export line to keep ignite-as-a-module working.
export = client;
