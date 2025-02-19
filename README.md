# Wagtail Deployment Script

## Overview
This script automates the deployment and configuration of a Wagtail project ( [Wagtail-bakery](https://github.com/wagtail-nest/wagtail-bakery/) )
  on a fresh Ubuntu server. It sets up the necessary dependencies, configures PostgreSQL, installs Wagtail, and runs the project with Gunicorn and Nginx.

## Features
- Automated setup of Wagtail on Ubuntu
- Creates a new system user for project isolation
- Configures PostgreSQL as the database backend
- Sets up Nginx as a reverse proxy
- Automatically applies migrations and collects static files
- Runs Wagtail with Gunicorn

## Prerequisites
Ensure that you have a fresh Ubuntu server and the following environment variables set:

```sh
export REMOTE_IP="your_server_ip"
export REMOTE_USER="your_ssh_user"
export REMOTE_PASS="your_ssh_password"
```

## Installation & Execution

1. Clone this repository:
   ```sh
   git clone https://github.com/yourusername/wagtail-auto-deploy.git
   cd wagtail-auto-deploy
   ```

2. Make the script executable:
   ```sh
   chmod +x deploy_wagtail.sh
   ```

3. Run the deployment script:
   ```sh
   ./deploy_wagtail.sh
   ```

(в соседней дирректории так же есть экспериментальый деплой с докером - он в работе, !не тестировался! )

The script will handle everything from installing dependencies to launching the Wagtail site.

## Quick Start
### Linux & macOS
1. Open a terminal and navigate to the script directory:
   ```sh
   cd wagtail-auto-deploy
   ```
2. Give execution permission to the script:
   ```sh
   chmod +x deploy_wagtail.sh
   ```
3. Run the script:
   ```sh
   ./deploy_wagtail.sh
   ```

### Windows (Using WSL or Git Bash)
1. Open a terminal (WSL, Git Bash, or PowerShell with WSL enabled).
2. Navigate to the script directory:
   ```sh
   cd wagtail-auto-deploy
   ```
3. Give execution permission:
   ```sh
   chmod +x deploy_wagtail.sh
   ```
4. Run the script:
   ```sh
   ./deploy_wagtail.sh
   ```

## Configuration Details
- **Database**: PostgreSQL (`wagtail_db`, user: `wagtail_user`, password: `yourpassword`)
- **Nginx Configuration**: Reverse proxy to Gunicorn on port 8000
- **Gunicorn**: Runs Wagtail application
- **Firewall Rules**: UFW allows SSH and Nginx

## Notes
- The script creates a new user `myuser` for the Wagtail project.
- Default admin credentials: `admin / adminpassword`
- Debug mode is enabled by default; adjust `mysite/settings/base.py` as needed.

## Acknowledgments
Inspired by [Wagtail](https://github.com/wagtail/wagtail/tree/main).

