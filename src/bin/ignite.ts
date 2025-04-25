#!/usr/bin/env node

// Check for older versions of Node no longer supported by the CLI.
import * as semver from "semver";
const pkg = require("../../package.json");
const nodeVersion = process.version;
if (!semver.satisfies(nodeVersion, pkg.engines.node)) {
  console.error(
    `Ignite CLI v${pkg.version} is incompatible with Node.js ${nodeVersion} Please upgrade Node.js to version ${pkg.engines.node}`
  );
  process.exit(1);
}

import { Command } from "commander";
import { join } from "path";
import * as fs from "fs";
import * as clc from "colorette";
import * as fsutils from "../fsutils";
import client, { errorOut } from "..";
import { configstore } from "../configstore";
const args = process.argv.slice(2);
let cmd: Command;

function findAvailableLogFile(): string {
  const candidates = ["firebase-debug.log"];
  for (let i = 1; i < 10; i++) {
    candidates.push(`firebase-debug.${i}.log`);
  }

  for (const c of candidates) {
    const logFilename = join(process.cwd(), c);

    try {
      const fd = fs.openSync(logFilename, "r+");
      fs.closeSync(fd);
      return logFilename;
    } catch (e: any) {
      if (e.code === "ENOENT") {
        // File does not exist, which is fine
        return logFilename;
      }

      // Any other error (EPERM, etc) means we won't be able to log to
      // this file so we skip it.
    }
  }

  throw new Error("Unable to obtain permissions for firebase-debug.log");
}

const logFilename = findAvailableLogFile();

if (!process.env.DEBUG && args.includes("--debug")) {
  process.env.DEBUG = "true";
}

process.env.IS_IGNITE_CLI = "true";

process.on("exit", (code) => {
  code = Number(process.exitCode) || code;
  if (!process.env.DEBUG && code < 2 && fsutils.fileExistsSync(logFilename)) {
    fs.unlinkSync(logFilename);
  }

  if (code > 0 && process.stdout.isTTY) {
    const lastError = configstore.get("lastError") || 0;
    const timestamp = Date.now();
    if (lastError > timestamp - 120000) {
      let help;
      if (code === 1 && cmd) {
        help = "Having trouble? Try " + clc.bold("firebase [command] --help");
      } else {
        help = "Having trouble? Try again or contact support with contents of ignite-debug.log";
      }

      if (cmd) {
        console.log();
        console.log(help);
      }
    }
    configstore.set("lastError", timestamp);
  } else {
    configstore.delete("lastError");
  }
});

process.on("uncaughtException", (err) => {
  errorOut(err);
});

if (!args.length) {
  client.cli.help();
} else {
  cmd = client.cli.parse(process.argv);
}
