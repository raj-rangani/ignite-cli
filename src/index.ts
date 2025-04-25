import { program } from "commander";
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

// NB: Keep this export line to keep firebase-tools-as-a-module working.
export = client;
