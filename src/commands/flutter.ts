import inquirer from "inquirer";
import { Command } from "../command";
import * as clc from "colorette";
import * as fs from "fs";
import { execSync } from "node:child_process";

interface FlutterConfig {
  projectName: string;
  orgId: string;
  flavors: string[];
  platforms: string[];
  useFirebase: boolean;
}

const HELP = `Interactively create and configure a Flutter project with flavors and CI/CD setup.`;

const command = new Command("init:flutter")
  .description("Create a new Flutter project with flavors and CI/CD setup")
  .help(HELP)
  .action(flutterAction);

export async function flutterAction(): Promise<void> {
  try {
    await new FlutterWorkflow().start();
  } catch (error) {
    console.error("Failed to initialize Flutter project:", error);
    throw error;
  }
}

export { command };

class FlutterWorkflow {
  private config: FlutterConfig = {
    projectName: "",
    orgId: "",
    flavors: [],
    platforms: [],
    useFirebase: false,
  };

  private async validateFlutterInstallation(): Promise<boolean> {
    try {
      execSync("flutter --version");
      return true;
    } catch (error) {
      console.error("Flutter SDK not found. Please install Flutter first.");
      console.info(
        "Visit https://flutter.dev/docs/get-started/install for installation instructions."
      );
      return false;
    }
  }

  private async validateProjectName(name: string): Promise<boolean> {
    // Flutter requires lowercase with underscores
    return /^[a-z][a-z0-9_]*$/.test(name);
  }

  private async validateOrgId(id: string): Promise<boolean> {
    // Should be a reverse domain format
    return /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(id);
  }

  public async start(): Promise<void> {
    console.info(clc.blue("🚀 Flutter Project Setup"));
    console.info("Welcome to the Flutter project setup workflow.\n");

    // Check Flutter installation
    if (!(await this.validateFlutterInstallation())) {
      console.info("Flutter SDK not found. Please install Flutter first.");
      return;
    }

    console.info("Validating Flutter installation...");
    // Get project name
    const { projectName } = await inquirer.prompt([
      {
        type: "input",
        name: "projectName",
        message: "Enter project name (lowercase with underscores, e.g., my_app):",
        validate: async (input: string) => {
          if (!input) return "Project name cannot be empty";
          const isValid = await this.validateProjectName(input);
          return (
            isValid ||
            "Invalid project name. Use lowercase letters, numbers, and underscores only, starting with a letter."
          );
        },
      },
    ]);
    this.config.projectName = projectName;

    // Get organization ID
    const { orgId } = await inquirer.prompt([
      {
        type: "input",
        name: "orgId",
        message: "Enter organization ID (reverse domain, e.g., com.example):",
        validate: async (input: string) => {
          if (!input) return "Organization ID cannot be empty";
          const isValid = await this.validateOrgId(input);
          return (
            isValid || "Invalid organization ID. Use reverse domain format (e.g., com.example)."
          );
        },
      },
    ]);
    this.config.orgId = orgId;

    // Select flavors
    const { flavors } = await inquirer.prompt([
      {
        type: "checkbox",
        name: "flavors",
        message: "Select flavors to include:",
        choices: [
          { name: "Development", value: "dev" },
          { name: "QA", value: "qa" },
          { name: "UAT", value: "uat" },
          { name: "Production", value: "prod" },
        ],
      },
    ]);
    this.config.flavors = flavors;

    // Select platforms
    const { platforms } = await inquirer.prompt([
      {
        type: "checkbox",
        name: "platforms",
        message: "Select target platforms:",
        choices: [
          { name: "Android", value: "android" },
          { name: "iOS", value: "ios" },
        ],
      },
    ]);
    this.config.platforms = platforms;

    // Ask about Firebase
    const { useFirebase } = await inquirer.prompt([
      {
        type: "confirm",
        name: "useFirebase",
        message: "Do you want to set up Firebase App Distribution?",
        default: false,
      },
    ]);
    this.config.useFirebase = useFirebase;

    // Confirm setup
    const { proceed } = await inquirer.prompt([
      {
        type: "confirm",
        name: "proceed",
        message: "Proceed with project creation?",
        default: true,
      },
    ]);

    if (!proceed) {
      console.info("Operation cancelled.");
      return;
    }

    // Create the project
    await this.createProject();
  }

  private async createProject(): Promise<void> {
    try {
      // Create Flutter project
      console.info("Creating Flutter project...");
      execSync(`flutter create --org "${this.config.orgId}" "${this.config.projectName}"`);

      // Change to project directory
      process.chdir(this.config.projectName);

      // Set up flavors if any selected
      if (this.config.flavors.length > 0) {
        await this.setupFlavors();
      }

      // Set up CI/CD if platforms selected
      if (this.config.platforms.length > 0) {
        await this.setupCICD();
      }

      console.info("\n✅ Flutter project created successfully!");
      console.info("\nNext steps:");
      console.info("1. cd into your project directory");
      console.info("2. Run your app: flutter run");
      if (this.config.flavors.length > 0) {
        console.info("3. Run with specific flavor: flutter run --flavor <flavor>");
      }
    } catch (error) {
      console.error("Failed to create Flutter project:", error);
      throw error;
    }
  }

  private async setupFlavors(): Promise<void> {
    console.info("Setting up flavors...");

    try {
      // Add flutter_flavorizr package as dev dependency
      execSync("flutter pub add flutter_flavorizr --dev");

      // Create flavor configuration in pubspec.yaml
      const pubspecPath = "pubspec.yaml";
      let pubspecContent = fs.readFileSync(pubspecPath, "utf8");

      // Add flavor configuration
      let flavorConfigYaml = `
# Flavor configuration
flavorizr:
  app:
    android:
      flavorDimensions: flavor-type
    ios: {}
  flavors:`;

      // Add each selected flavor
      for (const flavor of this.config.flavors) {
        const flavorName = flavor.toLowerCase();
        const appName =
          flavor === "prod"
            ? this.config.projectName
            : `${this.config.projectName} ${flavor.toUpperCase()}`;

        flavorConfigYaml += `
    ${flavorName}:
      app:
        name: ${appName}
      android:
        applicationId: ${this.config.orgId}.${this.config.projectName}${
          flavor === "prod" ? "" : `.${flavorName}`
        }
      ios:
        bundleId: ${this.config.orgId}.${this.config.projectName}${
          flavor === "prod" ? "" : `.${flavorName}`
        }`;
      }

      // Append flavor configuration to pubspec.yaml
      pubspecContent += flavorConfigYaml;
      fs.writeFileSync(pubspecPath, pubspecContent);

      // Create environment configuration
      await this.createEnvironmentConfig();

      // Run flutter_flavorizr to generate flavor configurations
      execSync("flutter pub run flutter_flavorizr");

      // Create flavor-specific main files
      for (const flavor of this.config.flavors) {
        const flavorName = flavor.toLowerCase();
        const mainFlavorPath = `lib/main_${flavorName}.dart`;
        const mainFlavorContent = `import 'package:flutter/material.dart';\nimport 'config/environment.dart';\nimport 'main.dart' as app;\n\nvoid main() {\n  AppConfig.setEnvironment(Environment.${flavorName});\n  app.main();\n}`;
        fs.writeFileSync(mainFlavorPath, mainFlavorContent);
      }

      // Update main.dart to include flavor configuration
      const mainPath = "lib/main.dart";
      let mainContent = fs.readFileSync(mainPath, "utf8");
      const importStatement =
        "import 'package:flutter/material.dart';\nimport 'config/environment.dart';\n\n";
      const mainFunction =
        "void main() {\n  // Default to prod environment if no flavor is selected\n  AppConfig.setEnvironment(Environment.prod);\n  runApp(const MyApp());\n}\n";

      mainContent = mainContent.replace(/import.*/, importStatement);
      mainContent = mainContent.replace(/void main.*?{.*?}/g, mainFunction);
      fs.writeFileSync(mainPath, mainContent);

      console.info("✅ Flutter flavors have been set up successfully!");
      console.info("You can now run your app with a specific flavor using:");
      for (const flavor of this.config.flavors) {
        console.info(
          `  flutter run --flavor ${flavor.toLowerCase()} -t lib/main_${flavor.toLowerCase()}.dart`
        );
      }
    } catch (error) {
      console.error("Failed to set up flavors:", error);
      throw error;
    }
  }

  private async createEnvironmentConfig(): Promise<void> {
    // Create environment configuration
    const envDir = "lib/config";
    if (!fs.existsSync(envDir)) {
      fs.mkdirSync(envDir, { recursive: true });
    }

    const envContent = `
enum Environment {
  ${this.config.flavors.map((f) => f.toLowerCase()).join(",\n  ")}
}

class AppConfig {
  static late Environment environment;
  static late String apiBaseUrl;
  static late bool enableLogging;

  static void setEnvironment(Environment env) {
    environment = env;
    
    switch (environment) {
      ${this.config.flavors
        .map((f) => {
          const flavor = f.toLowerCase();
          return `case Environment.${flavor}:
        apiBaseUrl = 'https://${flavor}-api.example.com';
        enableLogging = ${flavor !== "prod"};
        break;`;
        })
        .join("\n      ")}
    }
  }

  ${this.config.flavors
    .map((f) => {
      const flavor = f.toLowerCase();
      return `static bool is${
        f.charAt(0).toUpperCase() + f.slice(1)
      }() => environment == Environment.${flavor};`;
    })
    .join("\n  ")}
}`;

    fs.writeFileSync(`${envDir}/environment.dart`, envContent);
  }

  private async setupCICD(): Promise<void> {
    console.info("Setting up CI/CD...");

    try {
      // Create .github/workflows directory if it doesn't exist
      const workflowsDir = ".github/workflows";
      if (!fs.existsSync(workflowsDir)) {
        fs.mkdirSync(workflowsDir, { recursive: true });
      }

      // Create GitHub Actions workflow
      const workflowContent = `
name: Flutter CI/CD
    on:
    push:
        branches: [ main ]
    pull_request:
        branches: [ main ]
    workflow_dispatch:

    jobs:
    test:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v3
        - uses: subosito/flutter-action@v2
            with:
            flutter-version: '3.x'
        - run: flutter pub get
        - run: flutter test

    build-android:
        needs: test
        runs-on: ubuntu-latest
        if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
        steps:
        - uses: actions/checkout@v3
        - uses: actions/setup-java@v3
            with:
            distribution: 'zulu'
            java-version: '11'
        - uses: subosito/flutter-action@v2
            with:
            flutter-version: '3.x'
        - run: flutter pub get
        - run: flutter build appbundle --release
        - uses: r0adkll/sign-android-release@v1
            with:
            releaseDirectory: build/app/outputs/bundle/release
            signingKeyBase64: \${{ secrets.ANDROID_SIGNING_KEY }}
            alias: \${{ secrets.ANDROID_KEY_ALIAS }}
            keyStorePassword: \${{ secrets.ANDROID_KEY_STORE_PASSWORD }}
            keyPassword: \${{ secrets.ANDROID_KEY_PASSWORD }}
        - uses: r0adkll/upload-google-play@v1
            with:
            serviceAccountJsonPlainText: \${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
            packageName: ${this.config.orgId}.${this.config.projectName}
            releaseFiles: build/app/outputs/bundle/release/app-release.aab
            track: production
            status: completed

    build-ios:
        needs: test
        runs-on: macos-latest
        if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
        steps:
        - uses: actions/checkout@v3
        - uses: actions/setup-ruby@v1
            with:
            ruby-version: '2.7'
        - uses: subosito/flutter-action@v2
            with:
            flutter-version: '3.x'
        - run: flutter pub get
        - run: flutter build ios --release --no-codesign
        - run: |
            cd ios
            bundle install
            bundle exec fastlane beta
    `;

      fs.writeFileSync(`${workflowsDir}/flutter.yml`, workflowContent);

      // Set up Fastlane for Android if included
      if (this.config.platforms.includes("android")) {
        const androidFastfile = `
default_platform(:android)
    platform :android do
    desc "Deploy a new version to the Google Play"
    lane :deploy do
        gradle(
        task: "bundle",
        build_type: "Release"
        )
        upload_to_play_store
    end
end
`;

        const androidFastlaneDir = "android/fastlane";
        if (!fs.existsSync(androidFastlaneDir)) {
          fs.mkdirSync(androidFastlaneDir, { recursive: true });
        }
        fs.writeFileSync(`${androidFastlaneDir}/Fastfile`, androidFastfile);
      }

      // Set up Fastlane for iOS if included
      if (this.config.platforms.includes("ios")) {
        const iosFastfile = `
            default_platform(:ios)
                platform :ios do
                desc "Push a new beta build to TestFlight"
                lane :beta do
                    increment_build_number
                    build_ios_app
                    upload_to_testflight
                end

                desc "Deploy a new version to the App Store"
                lane :deploy do
                    increment_build_number
                    build_ios_app
                    upload_to_app_store
                end
            end
        `;

        const iosFastlaneDir = "ios/fastlane";
        if (!fs.existsSync(iosFastlaneDir)) {
          fs.mkdirSync(iosFastlaneDir, { recursive: true });
        }
        fs.writeFileSync(`${iosFastlaneDir}/Fastfile`, iosFastfile);
      }

      // Add CI/CD documentation to README.md
      const readmePath = "README.md";
      let readmeContent = fs.existsSync(readmePath) ? fs.readFileSync(readmePath, "utf8") : "";

      const cicdDocs = `\n
        ## CI/CD Setup
        ### Prerequisites
        - GitHub repository
        - Google Play Console account (for Android)
        - Apple Developer account (for iOS)
        - Fastlane installed locally for initial setup

        ### Deployment
        1. Android:
        - Create a service account in Google Play Console
        - Generate a signing key and store it securely
        - Add the following secrets to your GitHub repository:
            - \`ANDROID_SIGNING_KEY\`: Base64 encoded signing key
            - \`ANDROID_KEY_ALIAS\`: Key alias
            - \`ANDROID_KEY_STORE_PASSWORD\`: Keystore password
            - \`ANDROID_KEY_PASSWORD\`: Key password
            - \`GOOGLE_PLAY_SERVICE_ACCOUNT\`: Service account JSON

        2. iOS:
        - Create an App Store Connect API key
        - Add the following secrets to your GitHub repository:
            - \`APP_STORE_CONNECT_API_KEY\`: API key content
            - \`ITC_TEAM_ID\`: App Store Connect Team ID
            - \`ASC_KEY_ID\`: API key ID
            - \`ASC_ISSUER_ID\`: API key issuer ID
            - \`ASC_KEY_FILEPATH\`: Path to the API key file

        ### Integration
        The CI/CD pipeline is configured to:
        - Run tests on every push and pull request
        - Build and deploy Android app to Play Store on tag push
        - Build and deploy iOS app to TestFlight on tag push

        To trigger a deployment:
        1. Create and push a new tag: \`git tag -a v1.0.0 -m "Release 1.0.0"\`
        2. Push the tag: \`git push origin v1.0.0\`

        ### Checklist
        - [ ] Android:
        - [ ] Keystore file generated and stored securely
        - [ ] Google Play Console service account created
        - [ ] App metadata and screenshots uploaded
        - [ ] Release track configured
        - [ ] Signing configuration added to \`android/app/build.gradle\`

        - [ ] iOS:
        - [ ] App Store Connect API key created
        - [ ] App metadata and screenshots uploaded
        - [ ] Certificates and provisioning profiles set up
        - [ ] Fastlane match configured for code signing
        - [ ] App Store Connect API key stored securely

        - [ ] CI/CD:
        - [ ] GitHub repository secrets configured
        - [ ] Fastlane installed locally
        - [ ] Initial Fastlane setup completed
        - [ ] Test deployment successful
        - [ ] Monitoring and error reporting configured
       `;

      readmeContent += cicdDocs;
      fs.writeFileSync(readmePath, readmeContent);

      console.info("✅ CI/CD has been set up successfully!");
      console.info("Please configure the required secrets in your GitHub repository.");
    } catch (error) {
      console.error("Failed to set up CI/CD:", error);
      throw error;
    }
  }
}
