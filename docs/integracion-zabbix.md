# 🔗 Integración Oxidized + Zabbix

## 📋 Objetivo de la Integración

Crear un sistema completo de gestión de infraestructura que combine:
- **Monitoreo proactivo** (Zabbix)
- **Backup automático** de configuraciones (Oxidized)
- **Correlación de eventos** entre cambios y problemas
- **Alertas inteligentes** basadas en el contexto

## 🔧 Configuración de Monitoreo en Zabbix

### Items para Oxidized Service

1. **Estado del Servicio**
```
systemctl is-active oxidized
```

2. **Último Backup Exitoso**
```bash
# Script personalizado para obtener timestamp del último commit
#!/bin/bash
cd /var/lib/oxidized/oxidized.git
git log -1 --format="%ct" 2>/dev/null || echo "0"
```

3. **Número de Equipos Configurados**
```bash
grep -v "^#" /var/lib/oxidized/.config/oxidized/router.db | grep -v "^$" | wc -l
```

4. **API REST Disponibilidad**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/ | grep -q "200" && echo 1 || echo 0
```

### Triggers Recomendados

1. **Servicio Oxidized Caído**
   - Expression: `{Template:systemctl.is-active[oxidized].last()}=0`
   - Severity: High
   - Recovery: `{Template:systemctl.is-active[oxidized].last()}=1`

2. **Backup Desactualizado**
   - Expression: `{Template:oxidized.last-backup.last()}<now()-7200`
   - Severity: Warning
   - Recovery: `{Template:oxidized.last-backup.last()}>=now()-7200`
   - Descripción: "No se han realizado backups en las últimas 2 horas"

3. **API REST No Disponible**
   - Expression: `{Template:oxidized.api-check.last()}=0`
   - Severity: Average
   - Recovery: `{Template:oxidized.api-check.last()}=1`

## 🔄 Scripts de Integración

### Discovery de Equipos desde Zabbix

```bash
#!/bin/bash
# Script para generar router.db desde hosts de Zabbix
# Requiere: zabbix_api.py o similar

cat > /tmp/new_router.db << 'HEADER'
# Auto-generado desde Zabbix - $(date)
# Formato: name:ip:model:username:password:enable
HEADER

# Obtener hosts de Zabbix con grupo "Network devices"
# Este script debe ser personalizado según tu API de Zabbix
echo "# Equipos detectados automáticamente:" >> /tmp/new_router.db
echo "sc_mkt_ypf:192.168.60.15:ios:admin:admin:admin" >> /tmp/new_router.db

# Verificar cambios antes de aplicar
if ! diff /var/lib/oxidized/.config/oxidized/router.db /tmp/new_router.db >/dev/null 2>&1; then
    echo "Actualizando router.db..."
    cp /tmp/new_router.db /var/lib/oxidized/.config/oxidized/router.db
    chown oxidized:oxidized /var/lib/oxidized/.config/oxidized/router.db
    systemctl reload oxidized
fi
```

### Notificaciones de Cambios

```bash
#!/bin/bash
# Script para detectar cambios en configuraciones
# Se ejecuta cada 5 minutos via cron

LAST_CHECK_FILE="/tmp/oxidized_last_check"
CURRENT_TIME=$(date +%s)

# Si es la primera ejecución, solo crear el archivo de referencia
if [ ! -f "$LAST_CHECK_FILE" ]; then
    echo "$CURRENT_TIME" > "$LAST_CHECK_FILE"
    exit 0
fi

LAST_CHECK=$(cat "$LAST_CHECK_FILE")

# Buscar commits desde el último check
cd /var/lib/oxidized/oxidized.git
NEW_COMMITS=$(git log --since="@$LAST_CHECK" --format="%H %s" 2>/dev/null)

if [ -n "$NEW_COMMITS" ]; then
    # Enviar alerta a Zabbix
    while read -r commit message; do
        zabbix_sender -z localhost -s "Oxidized Server" -k "oxidized.config.change" -o "$message"
    done <<< "$NEW_COMMITS"
fi

echo "$CURRENT_TIME" > "$LAST_CHECK_FILE"
```

## 📊 Template de Zabbix para Oxidized

### Template XML (Fragmento)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<zabbix_export>
    <version>6.0</version>
    <templates>
        <template>
            <template>Template Oxidized Backup System</template>
            <name>Template Oxidized Backup System</name>
            <groups>
                <group>
                    <name>Templates/Network</name>
                </group>
            </groups>
            <items>
                <item>
                    <name>Oxidized Service Status</name>
                    <key>system.run[systemctl is-active oxidized]</key>
                    <value_type>TEXT</value_type>
                    <preprocessing>
                        <step>
                            <type>REGEX</type>
                            <params>^active$
1</params>
                        </step>
                    </preprocessing>
                </item>
                <item>
                    <name>Last Backup Timestamp</name>
                    <key>system.run[/opt/zabbix/scripts/oxidized_last_backup.sh]</key>
                    <value_type>UNSIGNED</value_type>
                    <units>unixtime</units>
                </item>
            </items>
        </template>
    </templates>
</zabbix_export>
```

## 🚨 Alertas Inteligentes

### Escenarios de Correlación

1. **Cambio Seguido de Problema**
   - Si hay un backup nuevo Y se activa una alerta de conectividad
   - Trigger compuesto que correlaciona timestamp de backup con problemas

2. **Backup Fallido Durante Mantenimiento**
   - Considerar períodos de maintenance al evaluar fallos de backup
   - Suprimir alertas durante ventanas de mantenimiento

3. **Detección de Drift de Configuración**
   - Comparar frecuencia de cambios vs. histórico
   - Alertar si hay demasiados cambios en poco tiempo

## 📈 Dashboard Integrado

### Widgets Recomendados

1. **Estado de Servicios**
   - Zabbix Server: ✅
   - Oxidized Service: ✅
   - PostgreSQL: ✅

2. **Métricas de Backup**
   - Equipos configurados: 1
   - Último backup: hace 5 min
   - Backups exitosos (24h): 24/24

3. **Gráfico de Actividad**
   - Commits por día (últimos 30 días)
   - Tiempo entre backups
   - Tasa de éxito de backups

## 🔧 Implementación Step-by-Step

### Paso 1: Items Básicos de Monitoreo
```bash
# Crear scripts de monitoreo
mkdir -p /opt/zabbix/scripts
cp Oxidized-Backup/scripts/* /opt/zabbix/scripts/
chmod +x /opt/zabbix/scripts/*
```

### Paso 2: Configurar User Parameters
```bash
# Agregar a zabbix_agent2.conf
echo "UserParameter=oxidized.service.status,systemctl is-active oxidized" >> /etc/zabbix/zabbix_agent2.conf
echo "UserParameter=oxidized.last.backup,/opt/zabbix/scripts/oxidized-last-backup.sh" >> /etc/zabbix/zabbix_agent2.conf
systemctl restart zabbix-agent2
```

### Paso 3: Importar Template
- Crear template en interface web de Zabbix
- Configurar items, triggers y gráficos
- Asignar template al host Zabbix server

### Paso 4: Configurar Alertas
- Configurar media types para notificaciones
- Crear actions basadas en triggers
- Probar escalations

---

**Estado:** Documentación para implementación
**Próximo paso:** Configurar items básicos en Zabbix
**Integración:** Lista para desarrollo
