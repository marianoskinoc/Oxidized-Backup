# Configuración Avanzada de Oxidized

## 🔧 Parámetros de Configuración

### Archivo Principal: `/var/lib/oxidized/.config/oxidized/config`

#### Configuración de Red
```yaml
# Timeouts y reintentos
timeout: 20          # Timeout por conexión (segundos)
retries: 3           # Número de reintentos
interval: 3600       # Intervalo entre backups (segundos)

# Configuración SSH
input:
  ssh:
    secure: false     # Permite conexiones SSH legacy
    port: 22          # Puerto SSH por defecto
    timeout: 30       # Timeout SSH específico
```

#### Configuración de Modelos
```yaml
# Mapeo de modelos de dispositivos
model_map:
  cisco: ios
  juniper: junos
  huawei: vrp
  hp: procurve
  mikrotik: routeros
  ubiquiti: airos
  fortinet: fortios
```

#### Configuración Git
```yaml
output:
  git:
    user: "Oxidized System"
    email: "oxidized@company.local"
    repo: "/var/lib/oxidized/oxidized.git"
    single_repo: true
```

## 📋 Base de Datos de Dispositivos

### Formato del archivo `router.db`

```csv
# Formato: nombre:ip:modelo:usuario:contraseña:enable_password
# Ejemplos por fabricante:

# MikroTik RouterOS
mikrotik-core:192.168.1.1:routeros:admin:password123:
mikrotik-edge:192.168.1.2:routeros:backup:backup456:

# Cisco IOS
cisco-sw01:192.168.1.10:ios:admin:cisco123:enable123
cisco-rt01:192.168.1.11:ios:netadmin:complex!pass:enable456

# Juniper JunOS
juniper-mx01:192.168.1.20:junos:root:juniper123:

# HP ProCurve
hp-sw01:192.168.1.30:procurve:manager:hp123:

# Ubiquiti EdgeOS
ubnt-er01:192.168.1.40:airos:admin:ubnt123:
```

### Variables por Grupos
```yaml
groups:
  core_switches:
    username: admin
    password: core_password
  edge_routers:
    username: netadmin
    password: edge_password
    enable: enable_password
```

## 🔍 Configuración de Monitoreo

### Scripts Personalizados

#### 1. Monitor de Conectividad
```bash
#!/bin/bash
# /opt/zabbix/scripts/oxidized-connectivity-check.sh

DEVICES_FILE="/var/lib/oxidized/.config/oxidized/router.db"
TOTAL_DEVICES=0
CONNECTED_DEVICES=0

while IFS=':' read -r name ip model user pass enable; do
    if [[ $name =~ ^[^#] ]] && [[ -n "$name" ]]; then
        TOTAL_DEVICES=$((TOTAL_DEVICES + 1))
        if timeout 5 nc -z "$ip" 22 2>/dev/null; then
            CONNECTED_DEVICES=$((CONNECTED_DEVICES + 1))
        fi
    fi
done < "$DEVICES_FILE"

if [ $TOTAL_DEVICES -gt 0 ]; then
    echo $((CONNECTED_DEVICES * 100 / TOTAL_DEVICES))
else
    echo 0
fi
```

#### 2. Análisis de Cambios
```bash
#!/bin/bash
# /opt/zabbix/scripts/oxidized-changes-count.sh

GIT_DIR="/var/lib/oxidized/oxidized.git"
if [ -d "$GIT_DIR" ]; then
    cd "$GIT_DIR"
    CHANGES=$(sudo -u oxidized git log --since="24 hours ago" --oneline | wc -l)
    echo $CHANGES
else
    echo 0
fi
```

### UserParameters Extendidos
```ini
# Agregar a /etc/zabbix/zabbix_agent2.conf

# Métricas básicas
UserParameter=oxidized.service.status,/opt/zabbix/scripts/oxidized-service-status.sh
UserParameter=oxidized.devices.count,/opt/zabbix/scripts/oxidized-devices-count.sh
UserParameter=oxidized.api.available,/opt/zabbix/scripts/oxidized-api-check.sh
UserParameter=oxidized.last.backup,/opt/zabbix/scripts/oxidized-last-backup.sh
UserParameter=oxidized.backup.status,/opt/zabbix/scripts/oxidized-backup-status.sh

# Métricas avanzadas
UserParameter=oxidized.connectivity.percentage,/opt/zabbix/scripts/oxidized-connectivity-check.sh
UserParameter=oxidized.changes.last24h,/opt/zabbix/scripts/oxidized-changes-count.sh
UserParameter=oxidized.repo.size,du -sb /var/lib/oxidized/oxidized.git | cut -f1
UserParameter=oxidized.memory.usage,ps -o rss= -p $(pgrep -f oxidized) | awk '{print $1*1024}'
```

## 🚀 Optimización de Rendimiento

### Configuración para Entornos Grandes
```yaml
# Para más de 100 dispositivos
threads: 50          # Hilos simultáneos
timeout: 30          # Timeout extendido
interval: 7200       # Backup cada 2 horas

# Configuración de memoria
vars:
  remove_secret: false
  ssh:
    compression: true
```

### Configuración de Logs
```yaml
# Logs detallados para troubleshooting
debug: true
log: "/var/log/oxidized/oxidized.log"
use_syslog: true
```

## 🔐 Seguridad y Autenticación

### Configuración SSH Segura
```yaml
input:
  ssh:
    secure: true
    host_key_verification: false
    keepalive: true
    keepalive_interval: 60
```

### Gestión de Credenciales
```bash
# Crear archivo de credenciales seguro
sudo chmod 600 /var/lib/oxidized/.config/oxidized/router.db
sudo chown oxidized:oxidized /var/lib/oxidized/.config/oxidized/router.db
```

### Configuración de Firewall
```bash
# Permitir puerto API (8888)
ufw allow 8888/tcp

# Permitir SSH saliente
ufw allow out 22/tcp
```

## 📊 API REST Extendida

### Endpoints Disponibles
```
GET  /nodes           # Lista todos los dispositivos
GET  /node/show/:name # Muestra configuración específica
POST /node/fetch/:name # Fuerza backup de dispositivo
GET  /node/stats/:name # Estadísticas del dispositivo
```

### Ejemplos de Uso
```bash
# Listar dispositivos
curl http://localhost:8888/nodes

# Forzar backup
curl -X POST http://localhost:8888/node/fetch/mikrotik-core

# Ver última configuración
curl http://localhost:8888/node/show/mikrotik-core
```

## 🔄 Configuración de Backup Incremental

### Configuración Git Avanzada
```yaml
output:
  git:
    repo: "/var/lib/oxidized/oxidized.git"
    single_repo: false
    repo_per_device: true
    user: "Oxidized Backup System"
    email: "oxidized@company.local"
```

### Hooks de Git
```bash
# /var/lib/oxidized/oxidized.git/hooks/post-commit
#!/bin/bash
# Notificar cambios vía webhook
curl -X POST https://hooks.company.com/oxidized \
     -H "Content-Type: application/json" \
     -d '{"device":"'$1'","timestamp":"'$(date)'","commit":"'$2'"}'
```

## 📧 Configuración de Alertas

### Integración con Email
```yaml
# Configuración SMTP (opcional)
hooks:
  cfg_changed:
    type: exec
    events: [post_store]
    cmd: '/opt/oxidized/notify-change.sh'
```

### Script de Notificación
```bash
#!/bin/bash
# /opt/oxidized/notify-change.sh

DEVICE=$1
TIMESTAMP=$(date)

echo "Configuración cambiada: $DEVICE en $TIMESTAMP" | \
mail -s "Oxidized: Cambio detectado" admin@company.com
```

## 🐳 Configuración Docker (Opcional)

### Dockerfile
```dockerfile
FROM ruby:3.1-alpine

RUN apk add --no-cache git openssh-client
RUN gem install oxidized

COPY config /root/.config/oxidized/
COPY router.db /root/.config/oxidized/

EXPOSE 8888
CMD ["oxidized"]
```

### docker-compose.yml
```yaml
version: '3.8'
services:
  oxidized:
    build: .
    ports:
      - "8888:8888"
    volumes:
      - ./configs:/root/.config/oxidized:ro
      - oxidized-git:/var/lib/oxidized/oxidized.git
    restart: unless-stopped

volumes:
  oxidized-git:
```

## 📈 Métricas Avanzadas

### Configuración Prometheus (Opcional)
```yaml
# Exportar métricas para Prometheus
rest: 0.0.0.0:8888
prometheus:
  enabled: true
  port: 9090
  path: /metrics
```

### Métricas Personalizadas
- Tiempo promedio de backup por dispositivo
- Tasa de éxito de conexiones
- Crecimiento del repositorio Git
- Uso de memoria y CPU

## 🔧 Troubleshooting Avanzado

### Logs Detallados
```bash
# Habilitar debug completo
echo "debug: true" >> /var/lib/oxidized/.config/oxidized/config
systemctl restart oxidized

# Monitorear logs en tiempo real
journalctl -u oxidized -f
```

### Análisis de Conectividad
```bash
# Probar conexión manual
ssh -o ConnectTimeout=10 usuario@dispositivo

# Verificar resolución DNS
nslookup dispositivo.company.local

# Probar alcance de red
traceroute dispositivo_ip
```

### Reset Completo
```bash
# Detener servicio
systemctl stop oxidized

# Limpiar repositorio Git
rm -rf /var/lib/oxidized/oxidized.git

# Reinicializar
sudo -u oxidized git init --bare /var/lib/oxidized/oxidized.git
systemctl start oxidized
```