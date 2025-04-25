export function load(client: any): any {
  function loadCommand(name: string) {
    const { command: cmd } = require(`./${name}`);
    cmd.register(client);
    return cmd.runner();
  }

  client.init = loadCommand("init");
  client["init:flutter"] = loadCommand("flutter");
  return client;
}
