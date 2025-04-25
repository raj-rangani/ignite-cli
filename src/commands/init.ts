import inquirer from "inquirer";
import { Command } from "../command";
import * as clc from "colorette";
import { join } from "path";
import { homedir } from "os";
import * as fs from "fs";
import { execSync } from "node:child_process";
import { promisify } from "util";

const execAsync = promisify(execSync);

interface ProjectConfig {
  techStack: string;
  framework: string;
  projectType: string;
  projectName: string;
  repoUrl?: string;
  architectureType?: string;
  backend?: {
    backendFramework: string;
    backendVersion: string;
  };
  frontend?: {
    frontendFramework: string;
    frontendVersion: string;
  };
  flavors?: string[];
  database?: string;
  cicd?: string;
  containerization?: string;
}

// const HELP = `Interactively configure the current directory as a Firebase project or initialize new features in an already configured Firebase project directory.`;

// const command = new Command("init")
//   .description("interactively configure the current directory as a Firebase project directory")
//   .help(HELP)
//   .action(initAction);

// export async function initAction(): Promise<void> {
//   try {
//     await new GuidedWorkflow().start();
//   } catch (error) {
//     console.error("Failed to initialize project:", error);
//     throw error;
//   }
// }

interface ProjectConfig {
  techStack: string;
  framework: string;
  projectType: string;
  projectName: string;
  repoUrl?: string;
  architectureType?: string;
  backend?: {
    backendFramework: string;
    backendVersion: string;
  };
  frontend?: {
    frontendFramework: string;
    frontendVersion: string;
  };
  flavors?: string[];
  database?: string;
  cicd?: string;
  containerization?: string;
}

const HELP = `Interactively configure the current directory as a Firebase project or initialize new features in an already configured Firebase project directory.`;

const command = new Command("init")
  .description("interactively configure the current directory as a Firebase project directory")
  .help(HELP)
  .action(initAction);

export async function initAction(): Promise<void> {
  try {
    await new GuidedWorkflow().start();
  } catch (error) {
    console.error("Failed to initialize project:", error);
    throw error;
  }
}

export { command };

export class GuidedWorkflow {
  private readonly STEP_NAMES = {
    1: "Init and TechStack Selection",
    2: "Framework Selection",
    3: "Project Source",
    4: "Project Structure",
    5: "Environment and Database Configuration",
    6: "Additional Environment Settings",
    7: "Installing Dependencies",
    8: "Useful Commands",
    9: "Completion",
  };

  private currentStep = 0;
  private markerDir: string;
  private config: ProjectConfig = {
    techStack: "",
    framework: "",
    projectType: "",
    projectName: "",
  };

  constructor() {
    this.markerDir = join(homedir(), `.dev-cli-markers-${Date.now()}`);
    try {
      fs.mkdirSync(this.markerDir, { recursive: true });
      console.debug(`Created marker directory: ${this.markerDir}`);
    } catch (error) {
      console.error(`Failed to create marker directory: ${error}`);
      throw error;
    }
  }

  private async trackStep(stepNumber: number, stepName: string): Promise<void> {
    this.currentStep = stepNumber;
    console.info(
      `\n${clc.blue("Step")} ${stepNumber}/${Object.keys(this.STEP_NAMES).length}: ${stepName}`
    );
  }

  private async validateGitUrl(url: string): Promise<boolean> {
    try {
      await execAsync(`git ls-remote ${url}`);
      return true;
    } catch (error) {
      return false;
    }
  }

  public async start(): Promise<void> {
    console.info(clc.blue("🚀 Ignite CLI Tool - Project Setup"));
    console.info(
      "Welcome to the project setup workflow. You will be guided through each step in sequence.\n"
    );

    // Step 1: TechStack Selection
    await this.trackStep(1, this.STEP_NAMES[1]);
    const { techStack } = await inquirer.prompt([
      {
        type: "list",
        name: "techStack",
        message: "Select your tech stack:",
        choices: [
          { name: "Frontend", value: "frontend" },
          { name: "Backend", value: "backend" },
          { name: "Mobile", value: "mobile" },
        ],
      },
    ]);
    this.config.techStack = techStack;

    // Step 2: Framework Selection
    await this.trackStep(2, this.STEP_NAMES[2]);
    const frameworkChoices = {
      frontend: ["React", "Angular", "Vue"],
      backend: ["Node.js (Express)", "Laravel (PHP)", "Django (Python)"],
      mobile: ["Flutter", "React Native"],
    };

    const { framework } = await inquirer.prompt([
      {
        type: "list",
        name: "framework",
        message: `Select your ${techStack} framework:`,
        choices: frameworkChoices[techStack as keyof typeof frameworkChoices],
      },
    ]);
    this.config.framework = framework;

    // Step 3: Project Source
    await this.trackStep(3, this.STEP_NAMES[3]);
    const { projectType } = await inquirer.prompt([
      {
        type: "list",
        name: "projectType",
        message: "Project Source:",
        choices: [
          { name: "New Project", value: "new" },
          { name: "Existing Project (Git Repository)", value: "existing" },
        ],
      },
    ]);
    this.config.projectType = projectType;

    if (projectType === "existing") {
      const { repoUrl } = await inquirer.prompt([
        {
          type: "input",
          name: "repoUrl",
          message: "Enter Git repository URL:",
          validate: async (input: string) => {
            if (!input) return "Repository URL cannot be empty";
            const isValid = await this.validateGitUrl(input);
            return isValid || "Invalid or unreachable repository URL";
          },
        },
      ]);
      this.config.repoUrl = repoUrl;
    }

    // Get project name
    const { projectName } = await inquirer.prompt([
      {
        type: "input",
        name: "projectName",
        message: "Enter project name:",
        default: this.config.repoUrl
          ? new URL(this.config.repoUrl).pathname.split("/").pop()?.replace(".git", "")
          : undefined,
        validate: (input: string) => input.length > 0 || "Project name cannot be empty",
      },
    ]);
    this.config.projectName = projectName;

    // Initialize project based on configuration
    await this.initializeProject();
  }

  private async initializeProject(): Promise<void> {
    const parentDir = process.cwd();
    const projectRoot = join(parentDir, this.config.projectName);

    try {
      if (!fs.existsSync(projectRoot)) {
        fs.mkdirSync(projectRoot, { recursive: true });
      }

      if (this.config.projectType === "new") {
        switch (this.config.framework.toLowerCase()) {
          case "node.js (express)":
            const boilerplateRepo = "https://github.com/hagopj13/node-express-boilerplate.git";
            await execAsync(`git clone ${boilerplateRepo} "${projectRoot}"`);
            process.chdir(projectRoot);
            fs.rmSync(join(projectRoot, ".git"), { recursive: true, force: true });
            await execAsync("git init");
            if (fs.existsSync(join(projectRoot, ".env.example"))) {
              fs.copyFileSync(join(projectRoot, ".env.example"), join(projectRoot, ".env"));
            }
            break;

          case "laravel (php)":
            if (!(await this.checkCommand("composer"))) {
              throw new Error(
                "Composer is not installed. Please install Composer to create a Laravel project."
              );
            }
            await execAsync(`composer create-project laravel/laravel "${projectRoot}"`);
            break;

          // Add other framework initializations as needed
          default:
            console.info(`Creating a new ${this.config.framework} project...`);
            // Add default project initialization
            break;
        }
      } else if (this.config.projectType === "existing") {
        process.chdir(projectRoot);
        await execAsync(`git clone "${this.config.repoUrl}" .`);
      }

      console.info(`\n✅ Project initialized successfully at: ${projectRoot}`);
      console.info("\nNext steps:");
      console.info("1. cd into your project directory");
      console.info("2. Install dependencies");
      console.info("3. Start development server\n");
    } catch (error) {
      console.error("Failed to initialize project:", error);
      throw error;
    }
  }

  private async checkCommand(command: string): Promise<boolean> {
    try {
      await execAsync(`command -v ${command}`);
      return true;
    } catch {
      return false;
    }
  }
}
