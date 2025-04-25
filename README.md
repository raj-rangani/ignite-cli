# Developer CLI Tool

A comprehensive command-line tool designed to streamline the development environment setup for mobile, backend, and frontend developers.

## Features

- Developer role selection (mobile, backend, frontend)
- Framework selection based on developer role
- Git repository cloning with branch selection
- Project structure generation for various frameworks
- Framework-specific configuration setup
- Development server configuration
- Dependency management
- Command list generation for selected frameworks

## Supported Frameworks

- **Mobile**: Flutter, React Native
- **Backend**: Node.js, Laravel
- **Frontend**: React, Vue, Angular

## Installation

### Prerequisites

- Bash shell
- Git
- Basic command-line knowledge

### Install from Source

1. Clone this repository:

```bash
git clone https://github.com/yourusername/dev-cli.git
cd dev-cli
```

2. Make the main script executable:

```bash
chmod +x bin/dev-cli.sh
```

3. Create a symbolic link to make it globally available (requires sudo):

```bash
sudo ln -s $(pwd)/bin/dev-cli.sh /usr/local/bin/dev-cli
```

## Usage

### Basic Usage

```bash
dev-cli [COMMAND] [OPTIONS]
```

### Available Commands

- `developer`: Select your developer role
- `framework`: Select a framework based on your role
- `clone`: Clone a Git repository
- `structure`: Generate project structure
- `configure`: Configure framework settings
- `server`: Configure server settings
- `dependencies`: Install dependencies
- `commands`: Show useful commands for selected framework

### Examples

Select your developer role:

```bash
dev-cli developer
```

Select a framework for your role:

```bash
dev-cli framework
```

Clone a repository:

```bash
dev-cli clone --repo=https://github.com/username/repo.git
```

Generate project structure:

```bash
dev-cli structure --framework=react
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by best practices from various development communities
- Built with Node.js and shell scripting
- Thanks to all contributors who have helped shape this tool

