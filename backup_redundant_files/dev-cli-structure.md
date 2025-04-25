# Developer CLI Tool - Project Structure

This document outlines the complete folder structure for the Developer CLI Tool project, with a focus on the implementation details. This CLI application is built using Bash shell scripts.

```
dev-cli/
├── bin/                             # CLI executable files
│   └── dev-cli.sh                   # Main CLI entry point (executable bash script)
│
├── src/                             # Source code
│   ├── commands/                    # CLI command implementations
│   │   ├── clone.sh                 # Git clone command
│   │   ├── developer.sh             # Developer role selection
│   │   ├── framework.sh             # Framework selection
│   │   ├── structure.sh             # Project structure generation
│   │   ├── configure.sh             # Framework configuration
│   │   ├── server.sh                # Server configuration
│   │   ├── command-list.sh          # Command list generation
│   │   └── dependencies.sh          # Dependency management
│   │
│   ├── templates/                   # Project templates for different frameworks
│   │   ├── mobile/                  # Mobile-specific templates
│   │   │   ├── flutter/             # Flutter template
│   │   │   │   └── ... (Flutter structure)
│   │   │   └── react-native/        # React Native template
│   │   │       └── ... (React Native structure)
│   │   │
│   │   ├── backend/                 # Backend-specific templates
│   │   │   ├── nodejs/              # Node.js template
│   │   │   │   └── ... (Node.js structure)
│   │   │   └── laravel/             # Laravel template
│   │   │       └── ... (Laravel structure)
│   │   │
│   │   └── frontend/                # Frontend-specific templates
│   │       ├── react/               # React template
│   │       │   └── ... (React structure)
│   │       ├── vue/                 # Vue template
│   │       │   └── ... (Vue structure)
│   │       └── angular/             # Angular template
│   │           └── ... (Angular structure)
│   │
│   ├── utils/                       # Utility functions
│   │   ├── git.sh                   # Git operations
│   │   ├── prompts.sh               # Interactive prompts
│   │   ├── logger.sh                # Logging utilities
│   │   ├── config.sh                # Configuration handling
│   │   ├── shell.sh                 # Shell command execution
│   │   └── validators.sh            # Input validation
│   │
│   └── scripts/                     # Role-specific setup scripts
│       ├── mobile.sh                # Mobile developer setup script
│       ├── backend.sh               # Backend developer setup script
│       └── frontend.sh              # Frontend developer setup script
│
├── docs/                            # Documentation
│   ├── developer-guides/            # Guides for different developer roles
│   │   ├── mobile-dev-guide.md      # Mobile development guide
│   │   ├── backend-dev-guide.md     # Backend development guide
│   │   └── frontend-dev-guide.md    # Frontend development guide
│   │
│   ├── framework-guides/            # Guides for different frameworks
│   │   ├── flutter-guide.md         # Flutter guide
│   │   ├── react-native-guide.md    # React Native guide
│   │   ├── nodejs-guide.md          # Node.js guide
│   │   └── laravel-guide.md         # Laravel guide
│   │
│   ├── command-references/          # Documentation for CLI commands
│   │   ├── flutter-commands.md      # Flutter commands
│   │   ├── react-native-commands.md # React Native commands
│   │   ├── nodejs-commands.md       # Node.js commands
│   │   └── laravel-commands.md      # Laravel commands
│   │
│   └── README.md                    # Main documentation
│
├── tests/                           # Test files
│   ├── commands/                    # Command tests (using bats framework)
│   ├── templates/                   # Template tests
│   └── utils/                       # Utility function tests
│
├── .gitignore                       # Git ignore file
└── README.md                        # Project README
```

## Key Components

### 1. CLI Entry Point

The `bin/dev-cli.sh` file serves as the main entry point for the CLI, making it executable from the command line. It's a Bash script that handles command routing and parameter parsing.

### 2. Core Command Scripts

The `src/commands/` directory contains shell scripts for each step in the CLI workflow:

- `clone.sh`: Handles Git repository cloning
- `developer.sh`: Manages developer role selection
- `framework.sh`: Handles framework selection based on developer role
- `structure.sh`: Generates project structure based on selected framework
- `configure.sh`: Configures framework-specific settings
- `server.sh`: Sets up server configuration
- `command-list.sh`: Generates useful commands for the selected framework
- `dependencies.sh`: Manages installation of dependencies

### 3. Templates

The `src/templates/` directory contains framework-specific templates organized by developer role:

- Mobile: Flutter, React Native
- Backend: Node.js, Laravel
- Frontend: React, Vue, Angular

### 4. Utility Scripts

The `src/utils/` directory contains utility shell scripts that provide common functionality:

- `git.sh`: Functions for Git operations
- `prompts.sh`: Functions for interactive user prompts
- `logger.sh`: Functions for formatted terminal output
- `config.sh`: Functions for managing configuration settings
- `shell.sh`: Functions for executing shell commands
- `validators.sh`: Functions for input validation

### 5. Role-Specific Scripts

The `src/scripts/` directory contains shell scripts (`mobile.sh`, `backend.sh`, `frontend.sh`) that can be executed for quick setup based on developer role.

### 6. Documentation

The `docs/` directory contains comprehensive documentation:

- Developer guides for different roles
- Framework-specific guides
- Command references for each framework

### 7. Tests

The `tests/` directory contains test files organized to mirror the structure of the `src/` directory. These tests can be implemented using a bash testing framework like [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System).
