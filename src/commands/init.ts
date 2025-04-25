import inquirer from "inquirer";
import { Command } from "../command";
import * as clc from "colorette";

const HELP = `Interactively configure the current directory as a Firebase project or initialize new features in an already configured Firebase project directory.`;

const command = new Command("init")
  .description("interactively configure the current directory as a Firebase project directory")
  .help(HELP)
  .action(initAction);

// Framework templates available
const frameworkTemplates = {
  backend: ["node", "laravel", "django", "spring-boot", "fastapi"],
  frontend: ["react", "vue", "angular", "flutter", "svelte"],
};

// Environment flavors
const environmentFlavors = ["production", "development", "staging", "qa", "sandbox"];
let projectConfig: {
  projectName: string;
  projectDescription: string;
  architectureType: string;
  backend: string;
  frontend: string;
  flavors: string[];
  database: string;
  cicd: string;
  containerization: string;
};

export async function initAction(): Promise<void> {
  console.log(projectConfig);
  try {
    console.log(clc.blue("🚀 Let's set up your development environment!"));

    // Project basics
    const projectBasics = await inquirer.prompt([
      {
        type: "input",
        name: "projectName",
        message: "What is your project name?",
        validate: (input) => input.length > 0 || "Project name cannot be empty",
      },
      {
        type: "input",
        name: "projectDescription",
        message: "Briefly describe your project:",
      },
    ]);

    projectConfig = { ...projectBasics };

    // Choose architecture style
    const { architectureType } = await inquirer.prompt([
      {
        type: "list",
        name: "architectureType",
        message: "What architecture pattern are you using?",
        choices: ["Monolithic", "Microservices", "Serverless", "Client-Server"],
      },
    ]);

    projectConfig.architectureType = architectureType;

    // Backend setup
    const backendSetup = await inquirer.prompt([
      {
        type: "list",
        name: "backendFramework",
        message: "Select your backend framework:",
        choices: frameworkTemplates.backend,
      },
      {
        type: "input",
        name: "backendVersion",
        message: (answers) => `Enter the version for ${answers.backendFramework}:`,
        default: "latest",
      },
    ]);

    projectConfig.backend = backendSetup;

    // Frontend setup
    const frontendSetup = await inquirer.prompt([
      {
        type: "list",
        name: "frontendFramework",
        message: "Select your frontend framework:",
        choices: frameworkTemplates.frontend,
      },
      {
        type: "input",
        name: "frontendVersion",
        message: (answers) => `Enter the version for ${answers.frontendFramework}:`,
        default: "latest",
      },
    ]);

    projectConfig.frontend = frontendSetup;

    // Environment flavors selection
    const { selectedFlavors } = await inquirer.prompt([
      {
        type: "checkbox",
        name: "selectedFlavors",
        message: "Select the environment flavors you need:",
        choices: environmentFlavors,
        default: ["development", "production"],
        validate: (input) => input.length > 0 || "You must select at least one environment",
      },
    ]);

    projectConfig.flavors = selectedFlavors;

    // Database selection
    const { database } = await inquirer.prompt([
      {
        type: "list",
        name: "database",
        message: "Select your primary database:",
        choices: ["MongoDB", "PostgreSQL", "MySQL", "SQLite", "None"],
      },
    ]);

    projectConfig.database = database;

    // CI/CD preferences
    const { cicdPreference } = await inquirer.prompt([
      {
        type: "list",
        name: "cicdPreference",
        message: "Select your CI/CD platform:",
        choices: ["GitHub Actions", "GitLab CI", "Jenkins", "CircleCI", "None"],
      },
    ]);

    projectConfig.cicd = cicdPreference;

    // Containerization
    const { containerization } = await inquirer.prompt([
      {
        type: "list",
        name: "containerization",
        message: "Do you want to use containerization?",
        choices: ["Docker", "Podman", "None"],
      },
    ]);

    projectConfig.containerization = containerization;

    // Save configuration
    // saveProjectConfig();

    console.log(clc.green("\n✅ Project configuration complete!\n"));
    console.log(clc.yellow("Next steps:"));
    console.log(
      clc.cyan("1. Run ") +
        clc.white("flowforge scaffold") +
        clc.cyan(" to generate project structure")
    );
    console.log(
      clc.cyan("2. Run ") +
        clc.white("flowforge deploy <flavor>") +
        clc.cyan(" to deploy to an environment\n")
    );
  } catch (err) {
    console.log("Error");
    throw err;
  }
}

export { command };
