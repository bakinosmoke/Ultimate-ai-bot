#!/bin/bash

# Ultimate AI Bot - Deployment Script
# 🇰🇭 POWERED BY CAMBODIA 🇰🇭

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BOT_NAME="ultimate-ai-bot"
VERSION="2.0.0"
DEPLOY_DIR="/opt/$BOT_NAME"
LOG_DIR="/var/log/$BOT_NAME"
BACKUP_DIR="/var/backup/$BOT_NAME"
SERVICE_NAME="$BOT_NAME.service"
ENV_FILE=".env"
GITHUB_REPO=""

# Banner
print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║    🤖  ULTIMATE AI BOT DEPLOYMENT SCRIPT  🤖                 ║"
    echo "║           🇰🇭  POWERED BY ANONYMOUS KHMER  🇰🇭               ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_warning "Running without root privileges. Some operations may fail."
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2)
    REQUIRED_VERSION=18
    if [[ $(echo "$NODE_VERSION < $REQUIRED_VERSION" | bc) -eq 1 ]]; then
        log_error "Node.js version $NODE_VERSION is below required version $REQUIRED_VERSION"
        exit 1
    fi
    log_info "Node.js version: $NODE_VERSION"
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        exit 1
    fi
    log_info "npm version: $(npm --version)"
    
    # Check Docker (optional)
    if command -v docker &> /dev/null; then
        log_info "Docker is available"
    else
        log_warning "Docker not found (optional for container deployment)"
    fi
    
    log_success "Prerequisites check passed"
}

# Create directory structure
create_directories() {
    log_step "Creating directory structure..."
    
    # Create deployment directory
    if [[ ! -d "$DEPLOY_DIR" ]]; then
        mkdir -p "$DEPLOY_DIR"
        chmod 755 "$DEPLOY_DIR"
        log_info "Created deployment directory: $DEPLOY_DIR"
    fi
    
    # Create log directory
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
        log_info "Created log directory: $LOG_DIR"
    fi
    
    # Create backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 755 "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
    
    log_success "Directory structure created"
}

# Backup existing installation
backup_existing() {
    log_step "Backing up existing installation..."
    
    if [[ -d "$DEPLOY_DIR" && "$(ls -A $DEPLOY_DIR 2>/dev/null)" ]]; then
        BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$BACKUP_FILE" -C "$DEPLOY_DIR" .
        log_info "Backup created: $BACKUP_FILE"
        log_success "Backup completed"
    else
        log_info "No existing installation found, skipping backup"
    fi
}

# Deploy from local source
deploy_local() {
    log_step "Deploying from local source..."
    
    # Copy files
    cp -r . "$DEPLOY_DIR/"
    
    # Set permissions
    chmod -R 755 "$DEPLOY_DIR"
    chmod 644 "$DEPLOY_DIR/$ENV_FILE" 2>/dev/null || true
    
    # Create symlink for logs
    ln -sf "$LOG_DIR" "$DEPLOY_DIR/logs"
    
    log_success "Files deployed to $DEPLOY_DIR"
}

# Deploy from GitHub
deploy_github() {
    if [[ -z "$GITHUB_REPO" ]]; then
        log_error "GitHub repository not specified in script"
        exit 1
    fi
    
    log_step "Deploying from GitHub: $GITHUB_REPO"
    
    if [[ -d "$DEPLOY_DIR/.git" ]]; then
        cd "$DEPLOY_DIR"
        git pull origin main
    else
        git clone "$GITHUB_REPO" "$DEPLOY_DIR"
    fi
    
    log_success "GitHub deployment completed"
}

# Install dependencies
install_dependencies() {
    log_step "Installing dependencies..."
    
    cd "$DEPLOY_DIR"
    
    if [[ -f "package.json" ]]; then
        log_info "Installing npm dependencies..."
        npm ci --only=production
        
        if [[ $? -eq 0 ]]; then
            log_success "Dependencies installed"
        else
            log_error "Failed to install dependencies"
            exit 1
        fi
    else
        log_error "package.json not found"
        exit 1
    fi
}

# Setup environment
setup_environment() {
    log_step "Setting up environment..."
    
    cd "$DEPLOY_DIR"
    
    # Check if .env exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_warning "$ENV_FILE not found, creating from template..."
        
        if [[ -f ".env.example" ]]; then
            cp .env.example "$ENV_FILE"
            log_info "Created $ENV_FILE from template"
            log_warning "Please edit $DEPLOY_DIR/$ENV_FILE with your credentials"
        else
            log_error ".env.example not found"
            exit 1
        fi
    else
        log_info "Using existing $ENV_FILE"
    fi
    
    # Validate required environment variables
    if [[ -f "$ENV_FILE" ]]; then
        if ! grep -q "BOT_TOKEN=" "$ENV_FILE"; then
            log_warning "BOT_TOKEN not found in $ENV_FILE"
        fi
        
        if ! grep -q "ADMIN_ID=" "$ENV_FILE"; then
            log_warning "ADMIN_ID not found in $ENV_FILE"
        fi
    fi
    
    log_success "Environment setup completed"
}

# Create systemd service
create_systemd_service() {
    log_step "Creating systemd service..."
    
    SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
    
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Ultimate AI Bot
Documentation=https://github.com/Anonymous-Khmer/ultimate-ai-bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$DEPLOY_DIR
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin
ExecStart=/usr/bin/node $DEPLOY_DIR/index.js
Restart=on-failure
RestartSec=10
StandardOutput=append:$LOG_DIR/bot.log
StandardError=append:$LOG_DIR/error.log

# Security
NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ReadWritePaths=$LOG_DIR $DEPLOY_DIR/data

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "$SERVICE_PATH"
    systemctl daemon-reload
    
    log_success "Systemd service created: $SERVICE_NAME"
}

# Setup monitoring
setup_monitoring() {
    log_step "Setting up monitoring..."
    
    # Create health check cron job
    CRON_JOB="*/5 * * * * cd $DEPLOY_DIR && /usr/bin/node scripts/health-check.js --single >> $LOG_DIR/health-check.log 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "health-check.js"; echo "$CRON_JOB") | crontab -
    
    # Create log rotation
    LOGROTATE_PATH="/etc/logrotate.d/$BOT_NAME"
    
    cat > "$LOGROTATE_PATH" << EOF
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
    
    chmod 644 "$LOGROTATE_PATH"
    
    log_success "Monitoring setup completed"
}

# Start the service
start_service() {
    log_step "Starting $SERVICE_NAME..."
    
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    # Wait and check status
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service started successfully"
        
        # Show service status
        echo ""
        systemctl status "$SERVICE_NAME" --no-pager -l
        
        # Show logs
        echo -e "\n${CYAN}📋 Recent logs:${NC}"
        tail -20 "$LOG_DIR/bot.log" 2>/dev/null || echo "No logs yet"
        
    else
        log_error "Failed to start service"
        journalctl -u "$SERVICE_NAME" --no-pager -n 50
        exit 1
    fi
}

# Health check
perform_health_check() {
    log_step "Performing health check..."
    
    sleep 5  # Give time for service to start
    
    if [[ -f "$DEPLOY_DIR/scripts/health-check.js" ]]; then
        cd "$DEPLOY_DIR"
        
        # Run single health check
        if node scripts/health-check.js --single; then
            log_success "Health check passed"
        else
            log_warning "Health check failed, but service may still be starting"
        fi
    else
        log_warning "Health check script not found, skipping"
    fi
    
    # Check if service is responding
    if curl -s http://localhost:8080/health > /dev/null; then
        log_success "Health endpoint is responding"
    else
        log_warning "Health endpoint not responding yet"
    fi
}

# Show deployment summary
show_summary() {
    log_step "Deployment Summary"
    
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    DEPLOYMENT COMPLETE!                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}📊 Deployment Details:${NC}"
    echo "  • Bot Name:      $BOT_NAME v$VERSION"
    echo "  • Deployment Dir: $DEPLOY_DIR"
    echo "  • Log Directory:  $LOG_DIR"
    echo "  • Service:        $SERVICE_NAME"
    
    echo -e "\n${CYAN}🚀 Service Commands:${NC}"
    echo "  Start:    sudo systemctl start $SERVICE_NAME"
    echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
    echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
    echo "  Status:   sudo systemctl status $SERVICE_NAME"
    echo "  Logs:     sudo journalctl -u $SERVICE_NAME -f"
    
    echo -e "\n${CYAN}📁 Important Files:${NC}"
    echo "  • Config:        $DEPLOY_DIR/$ENV_FILE"
    echo "  • Bot Script:    $DEPLOY_DIR/ultimate-ai-bot.js"
    echo "  • Logs:          $LOG_DIR/"
    echo "  • Backups:       $BACKUP_DIR/"
    
    echo -e "\n${CYAN}🔍 Health Check:${NC}"
    echo "  • Endpoint:      http://localhost:8080/health"
    echo "  • Status:        http://localhost:8080/status"
    echo "  • Manual Check:  node $DEPLOY_DIR/scripts/health-check.js"
    
    echo -e "\n${CYAN}📈 Monitoring:${NC}"
    echo "  • Health checks run every 5 minutes"
    echo "  • Logs rotated daily (7 days retention)"
    
    echo -e "\n${YELLOW}⚠️  Next Steps:${NC}"
    echo "  1. Edit configuration: nano $DEPLOY_DIR/$ENV_FILE"
    echo "  2. Add your BOT_TOKEN and ADMIN_ID"
    echo "  3. Restart service: sudo systemctl restart $SERVICE_NAME"
    echo "  4. Test bot: Send /start to @bakixzrck_bot"
    
    echo -e "\n${MAGENTA}🇰🇭 Bot is now deployed and running! 🇰🇭${NC}"
}

# Main deployment function
deploy() {
    print_banner
    
    log_info "Starting deployment of $BOT_NAME v$VERSION"
    log_info "Timestamp: $(date)"
    log_info "User: $USER"
    
    # Check prerequisites
    check_prerequisites
    
    # Create directories
    create_directories
    
    # Backup existing
    backup_existing
    
    # Deploy based on source
    if [[ "$1" == "github" ]]; then
        deploy_github
    else
        deploy_local
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup environment
    setup_environment
    
    # Create systemd service
    create_systemd_service
    
    # Setup monitoring
    setup_monitoring
    
    # Start service
    start_service
    
    # Health check
    perform_health_check
    
    # Show summary
    show_summary
}

# Update function
update() {
    print_banner
    
    log_step "Updating $BOT_NAME..."
    
    # Backup first
    backup_existing
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Stopping service..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Update from source
    if [[ "$1" == "github" ]]; then
        deploy_github
    else
        log_info "Pull latest changes..."
        cd "$DEPLOY_DIR"
        git pull origin main
    fi
    
    # Install dependencies
    install_dependencies
    
    # Restart service
    log_info "Restarting service..."
    systemctl restart "$SERVICE_NAME"
    
    log_success "Update completed"
    
    # Show status
    systemctl status "$SERVICE_NAME" --no-pager -l
}

# Uninstall function
uninstall() {
    print_banner
    
    log_warning "⚠️  This will uninstall $BOT_NAME and remove all data!"
    
    read -p "Are you sure? (yes/no): " -n 3 -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
    
    log_step "Stopping service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    log_step "Removing service file..."
    rm -f "/etc/systemd/system/$SERVICE_NAME"
    systemctl daemon-reload
    
    log_step "Removing cron jobs..."
    crontab -l 2>/dev/null | grep -v "health-check.js" | crontab -
    
    log_step "Removing log rotation..."
    rm -f "/etc/logrotate.d/$BOT_NAME"
    
    log_step "Backup data..."
    BACKUP_FILE="$BACKUP_DIR/final_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" -C "$DEPLOY_DIR" .
    log_info "Final backup created: $BACKUP_FILE"
    
    log_step "Removing directories..."
    rm -rf "$DEPLOY_DIR"
    # Keep logs and backups for reference
    # rm -rf "$LOG_DIR"
    # rm -rf "$BACKUP_DIR"
    
    log_success "Uninstallation completed"
    log_info "Backups preserved at: $BACKUP_DIR"
}

# Show help
show_help() {
    print_banner
    
    echo -e "${CYAN}Usage: $0 [command]${NC}"
    echo ""
    echo -e "${GREEN}Commands:${NC}"
    echo "  deploy        Deploy the bot (default)"
    echo "  deploy-github Deploy from GitHub repository"
    echo "  update        Update existing installation"
    echo "  update-github Update from GitHub"
    echo "  uninstall     Remove the bot"
    echo "  status        Show bot status"
    echo "  logs          Show bot logs"
    echo "  help          Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 deploy           # Deploy from local source"
    echo "  $0 deploy-github    # Deploy from GitHub"
    echo "  $0 update           # Update from local source"
    echo "  $0 status           # Check bot status"
    echo ""
    echo -e "${MAGENTA}🇰🇭 Anonymous Khmer - Ultimate AI Bot 🇰🇭${NC}"
}

# Check status
check_status() {
    print_banner
    
    log_step "Checking $BOT_NAME status..."
    
    echo -e "${CYAN}📊 System Status:${NC}"
    
    # Check service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "  Service: ${GREEN}Running ✅${NC}"
    else
        echo -e "  Service: ${RED}Stopped ❌${NC}"
    fi
    
    # Show service status
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l
    
    # Check health endpoint
    echo -e "\n${CYAN}🌐 Health Check:${NC}"
    if curl -s --max-time 5 http://localhost:8080/health > /dev/null; then
        echo -e "  Health endpoint: ${GREEN}Responding ✅${NC}"
        curl -s http://localhost:8080/health | python3 -m json.tool 2>/dev/null || echo "  Response received"
    else
        echo -e "  Health endpoint: ${RED}Not responding ❌${NC}"
    fi
    
    # Show logs
    echo -e "\n${CYAN}📋 Recent Logs:${NC}"
    tail -20 "$LOG_DIR/bot.log" 2>/dev/null || echo "  No logs found"
}

# Show logs
show_logs() {
    print_banner
    
    log_step "Showing logs for $BOT_NAME..."
    
    echo -e "${CYAN}Options:${NC}"
    echo "  1. Bot logs (default)"
    echo "  2. Error logs"
    echo "  3. Health check logs"
    echo "  4. All logs (follow)"
    echo ""
    read -p "Select option (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            tail -f "$LOG_DIR/bot.log"
            ;;
        2)
            tail -f "$LOG_DIR/error.log"
            ;;
        3)
            tail -f "$LOG_DIR/health-check.log"
            ;;
        4)
            multitail "$LOG_DIR/bot.log" "$LOG_DIR/error.log" "$LOG_DIR/health-check.log"
            ;;
        *)
            tail -f "$LOG_DIR/bot.log"
            ;;
    esac
}

# Main script
main() {
    case "$1" in
        "deploy")
            deploy "local"
            ;;
        "deploy-github")
            deploy "github"
            ;;
        "update")
            update "local"
            ;;
        "update-github")
            update "github"
            ;;
        "uninstall")
            uninstall
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            deploy "local"
            ;;
    esac
}

# Run main function
main "$1"