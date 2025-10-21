#!/bin/bash

# Oxidized-Backup Installation Script
# Autor: marianoskinoc
# Fecha: 2025-10-21
# Descripción: Script automático de instalación de Oxidized con monitoreo Zabbix

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verificar si se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Verificar distribución del sistema
check_system() {
    if [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        log_info "Sistema Debian/Ubuntu detectado"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="redhat"
        log_info "Sistema RedHat/CentOS detectado"
    else
        log_error "Distribución no soportada"
        exit 1
    fi
}

# Actualizar sistema
update_system() {
    log_info "Actualizando sistema..."
    if [[ "$DISTRO" == "debian" ]]; then
        apt update && apt upgrade -y
    elif [[ "$DISTRO" == "redhat" ]]; then
        yum update -y
    fi
    log_success "Sistema actualizado"
}

# Instalar dependencias del sistema
install_dependencies() {
    log_info "Instalando dependencias del sistema..."
    
    if [[ "$DISTRO" == "debian" ]]; then
        apt install -y ruby ruby-dev build-essential git \
                       libssh2-1-dev cmake pkg-config libgit2-dev \
                       libyaml-dev libicu-dev curl netcat-openbsd
    elif [[ "$DISTRO" == "redhat" ]]; then
        yum install -y ruby ruby-devel gcc gcc-c++ make git \
                       libssh2-devel cmake pkgconfig libgit2-devel \
                       libyaml-devel libicu-devel curl nc
    fi
    
    log_success "Dependencias del sistema instaladas"
}

# Instalar gems de Ruby
install_ruby_gems() {
    log_info "Instalando gems de Ruby..."
    
    gem install oxidized
    gem install net-ssh
    gem install rugged
    
    log_success "Gems de Ruby instaladas"
}

# Crear usuario oxidized
create_user() {
    log_info "Creando usuario oxidized..."
    
    if ! id "oxidized" &>/dev/null; then
        useradd -r -m -d /var/lib/oxidized -s /bin/bash oxidized
        log_success "Usuario oxidized creado"
    else
        log_warning "Usuario oxidized ya existe"
    fi
}

# Crear directorios necesarios
create_directories() {
    log_info "Creando estructura de directorios..."
    
    mkdir -p /var/lib/oxidized/.config/oxidized
    mkdir -p /opt/zabbix/scripts
    mkdir -p /var/log/oxidized
    
    # Cambiar propietarios
    chown -R oxidized:oxidized /var/lib/oxidized
    chown -R zabbix:zabbix /opt/zabbix/scripts 2>/dev/null || chown -R root:root /opt/zabbix/scripts
    
    log_success "Directorios creados"
}

# Crear configuración de Oxidized
create_oxidized_config() {
    log_info "Creando configuración de Oxidized..."
    
    cat > /var/lib/oxidized/.config/oxidized/config << 'EOF'
---
username: admin
password: admin
model: junos
resolve_dns: false
interval: 3600
use_syslog: false
debug: false
threads: 30
timeout: 20
retries: 3
prompt: !ruby/regexp /^([\w.@-]+[#>]\s?)$/
next_adds_job: false
vars: {}
groups: {}
rest: 0.0.0.0:8888
web: 0.0.0.0:8888
pid: /var/lib/oxidized/oxidized.pid

input:
  default: ssh, telnet
  debug: false
  ssh:
    secure: false
  telnet:
    port: 23

output:
  default: git
  git:
    user: Oxidized
    email: oxidized@oxidized.local
    repo: /var/lib/oxidized/oxidized.git

source:
  default: csv
  csv:
    file: /var/lib/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      ip: 1
      model: 2
      username: 3
      password: 4
    vars_map:
      enable: 5

model_map:
  cisco: ios
  juniper: junos
  huawei: vrp
  hp: procurve
  mikrotik: routeros
  ubiquiti: airos
EOF

    # Crear archivo de dispositivos de ejemplo
    cat > /var/lib/oxidized/.config/oxidized/router.db << 'EOF'
# Archivo de configuración de dispositivos
# Formato: nombre:ip:modelo:usuario:contraseña:enable_password
# Ejemplos:
# mikrotik01:192.168.1.1:routeros:admin:password123:
# cisco-sw01:192.168.1.10:ios:admin:cisco123:enable123
# juniper01:192.168.1.20:junos:root:juniper123:

# Agregar aquí tus dispositivos
EOF

    chown -R oxidized:oxidized /var/lib/oxidized
    log_success "Configuración de Oxidized creada"
}

# Crear scripts de monitoreo
create_monitoring_scripts() {
    log_info "Creando scripts de monitoreo Zabbix..."
    
    # Script 1: Estado del servicio
    cat > /opt/zabbix/scripts/oxidized-service-status.sh << 'EOF'
#!/bin/bash
if systemctl is-active --quiet oxidized; then
    echo 1
else
    echo 0
fi
EOF

    # Script 2: Contador de dispositivos
    cat > /opt/zabbix/scripts/oxidized-devices-count.sh << 'EOF'
#!/bin/bash
if [ -f "/var/lib/oxidized/.config/oxidized/router.db" ]; then
    grep -v "^#" /var/lib/oxidized/.config/oxidized/router.db | grep -v "^$" | wc -l
else
    echo 0
fi
EOF

    # Script 3: Verificador de API
    cat > /opt/zabbix/scripts/oxidized-api-check.sh << 'EOF'
#!/bin/bash
if curl -s --max-time 5 http://127.0.0.1:8888 > /dev/null 2>&1; then
    echo 1
else
    echo 0
fi
EOF

    # Script 4: Último backup
    cat > /opt/zabbix/scripts/oxidized-last-backup.sh << 'EOF'
#!/bin/bash
if [ -d "/var/lib/oxidized/oxidized.git" ]; then
    cd /var/lib/oxidized/oxidized.git
    TIMESTAMP=$(sudo -u oxidized git log -1 --format="%ct" 2>/dev/null)
    if [ -n "$TIMESTAMP" ]; then
        echo $TIMESTAMP
    else
        echo 0
    fi
else
    echo 0
fi
EOF

    # Script 5: Estado de backups
    cat > /opt/zabbix/scripts/oxidized-backup-status.sh << 'EOF'
#!/bin/bash
if [ -d "/var/lib/oxidized/oxidized.git" ]; then
    cd /var/lib/oxidized/oxidized.git
    TIMESTAMP=$(sudo -u oxidized git log -1 --format="%ct" 2>/dev/null)
    if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" -gt 0 ]; then
        CURRENT_TIME=$(date +%s)
        DIFF=$((CURRENT_TIME - TIMESTAMP))
        if [ $DIFF -lt 7200 ]; then
            echo 1
        else
            echo 2
        fi
    else
        echo 0
    fi
else
    echo 0
fi
EOF

    # Hacer ejecutables
    chmod +x /opt/zabbix/scripts/oxidized-*.sh
    
    log_success "Scripts de monitoreo creados"
}

# Crear servicio systemd
create_systemd_service() {
    log_info "Creando servicio systemd..."
    
    cat > /etc/systemd/system/oxidized.service << 'EOF'
[Unit]
Description=Oxidized Network Device Configuration Backup Tool
After=network.target

[Service]
Type=simple
User=oxidized
Group=oxidized
WorkingDirectory=/var/lib/oxidized
ExecStart=/usr/local/bin/oxidized
Restart=always
RestartSec=10
Environment=HOME=/var/lib/oxidized

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "Servicio systemd creado"
}

# Inicializar repositorio Git
init_git_repo() {
    log_info "Inicializando repositorio Git..."
    
    sudo -u oxidized git init --bare /var/lib/oxidized/oxidized.git
    chown -R oxidized:oxidized /var/lib/oxidized/oxidized.git
    
    log_success "Repositorio Git inicializado"
}

# Configurar UserParameters para Zabbix
configure_zabbix_userparameters() {
    log_info "Configurando UserParameters de Zabbix..."
    
    # Crear archivo de UserParameters
    cat > /tmp/oxidized-userparameters.conf << 'EOF'

# Oxidized Monitoring UserParameters
UserParameter=oxidized.service.status,/opt/zabbix/scripts/oxidized-service-status.sh
UserParameter=oxidized.devices.count,/opt/zabbix/scripts/oxidized-devices-count.sh
UserParameter=oxidized.api.available,/opt/zabbix/scripts/oxidized-api-check.sh
UserParameter=oxidized.last.backup,/opt/zabbix/scripts/oxidized-last-backup.sh
UserParameter=oxidized.backup.status,/opt/zabbix/scripts/oxidized-backup-status.sh
EOF

    # Agregar al archivo de configuración de Zabbix
    if [[ -f /etc/zabbix/zabbix_agent2.conf ]]; then
        cat /tmp/oxidized-userparameters.conf >> /etc/zabbix/zabbix_agent2.conf
        rm /tmp/oxidized-userparameters.conf
        log_success "UserParameters agregados a zabbix_agent2.conf"
    elif [[ -f /etc/zabbix/zabbix_agentd.conf ]]; then
        cat /tmp/oxidized-userparameters.conf >> /etc/zabbix/zabbix_agentd.conf
        rm /tmp/oxidized-userparameters.conf
        log_success "UserParameters agregados a zabbix_agentd.conf"
    else
        log_warning "Archivo de configuración de Zabbix no encontrado"
        log_info "UserParameters guardados en /tmp/oxidized-userparameters.conf"
    fi
}

# Configurar firewall
configure_firewall() {
    log_info "Configurando firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 8888/tcp comment "Oxidized Web Interface"
        log_success "Regla de firewall agregada (UFW)"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=8888/tcp
        firewall-cmd --reload
        log_success "Regla de firewall agregada (firewalld)"
    else
        log_warning "No se detectó sistema de firewall, configure manualmente el puerto 8888"
    fi
}

# Habilitar y iniciar servicios
start_services() {
    log_info "Habilitando e iniciando servicios..."
    
    # Habilitar Oxidized
    systemctl enable oxidized
    systemctl start oxidized
    
    # Reiniciar Zabbix Agent si está disponible
    if systemctl list-unit-files | grep -q zabbix-agent2; then
        systemctl restart zabbix-agent2
        log_success "Zabbix Agent 2 reiniciado"
    elif systemctl list-unit-files | grep -q zabbix-agent; then
        systemctl restart zabbix-agent
        log_success "Zabbix Agent reiniciado"
    else
        log_warning "Servicio Zabbix Agent no encontrado"
    fi
    
    log_success "Servicios iniciados"
}

# Verificar instalación
verify_installation() {
    log_info "Verificando instalación..."
    
    # Verificar servicio Oxidized
    if systemctl is-active --quiet oxidized; then
        log_success "✓ Servicio Oxidized está ejecutándose"
    else
        log_error "✗ Servicio Oxidized no está ejecutándose"
    fi
    
    # Verificar API
    if curl -s --max-time 5 http://127.0.0.1:8888 >/dev/null 2>&1; then
        log_success "✓ API web está accesible en puerto 8888"
    else
        log_warning "✗ API web no está accesible"
    fi
    
    # Verificar scripts de monitoreo
    local script_errors=0
    for script in service-status devices-count api-check last-backup backup-status; do
        if /opt/zabbix/scripts/oxidized-${script}.sh >/dev/null 2>&1; then
            log_success "✓ Script oxidized-${script}.sh funciona"
        else
            log_error "✗ Script oxidized-${script}.sh tiene errores"
            ((script_errors++))
        fi
    done
    
    if [[ $script_errors -eq 0 ]]; then
        log_success "✓ Todos los scripts de monitoreo funcionan correctamente"
    fi
    
    # Verificar repositorio Git
    if [[ -d /var/lib/oxidized/oxidized.git ]]; then
        log_success "✓ Repositorio Git inicializado"
    else
        log_error "✗ Repositorio Git no encontrado"
    fi
}

# Mostrar información post-instalación
show_post_install_info() {
    echo
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                    INSTALACIÓN COMPLETADA                             ║"
    echo "╠════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                        ║"
    echo "║  🌐 Interfaz Web: http://$(hostname -I | awk '{print $1}'):8888                          ║"
    echo "║  📁 Configuración: /var/lib/oxidized/.config/oxidized/config          ║"
    echo "║  📋 Dispositivos: /var/lib/oxidized/.config/oxidized/router.db        ║"
    echo "║  📊 Scripts Monitoreo: /opt/zabbix/scripts/                           ║"
    echo "║  📚 Repositorio Git: /var/lib/oxidized/oxidized.git                   ║"
    echo "║                                                                        ║"
    echo "║  PRÓXIMOS PASOS:                                                       ║"
    echo "║  1. Editar router.db con tus dispositivos                             ║"
    echo "║  2. Importar template Zabbix (templates/zabbix-template-oxidized.xml) ║"
    echo "║  3. Configurar host en Zabbix con template                            ║"
    echo "║  4. Verificar backups en interfaz web                                 ║"
    echo "║                                                                        ║"
    echo "║  COMANDOS ÚTILES:                                                      ║"
    echo "║  • systemctl status oxidized                                          ║"
    echo "║  • journalctl -u oxidized -f                                          ║"
    echo "║  • curl http://localhost:8888/nodes                                   ║"
    echo "║                                                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo
}

# Función principal
main() {
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║              INSTALADOR OXIDIZED-BACKUP v1.0                          ║"
    echo "║              Autor: marianoskinoc                                      ║"
    echo "║              Fecha: $(date +'%Y-%m-%d')                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo
    
    check_root
    check_system
    
    log_info "Iniciando instalación de Oxidized-Backup..."
    echo
    
    update_system
    install_dependencies
    install_ruby_gems
    create_user
    create_directories
    create_oxidized_config
    create_monitoring_scripts
    create_systemd_service
    init_git_repo
    configure_zabbix_userparameters
    configure_firewall
    start_services
    
    echo
    log_info "Verificando instalación..."
    verify_installation
    
    echo
    show_post_install_info
}

# Ejecutar instalación
main "$@"