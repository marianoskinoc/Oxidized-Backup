#!/bin/bash

# Script para verificar estado de Oxidized y backups
# Autor: marianoskinoc
# Fecha: $(date '+%Y-%m-%d')

echo "=========================================="
echo "🔄 ESTADO DE OXIDIZED BACKUP SYSTEM"
echo "=========================================="
echo

# Verificar servicio Oxidized
echo "📊 Estado del servicio Oxidized:"
echo "--------------------------------"
systemctl is-active oxidized >/dev/null && echo "✅ Servicio oxidized: ACTIVO" || echo "❌ Servicio oxidized: INACTIVO"
systemctl is-enabled oxidized >/dev/null && echo "✅ Autostart: HABILITADO" || echo "❌ Autostart: DESHABILITADO"
echo

# Verificar archivos de configuración
echo "⚙️  Archivos de configuración:"
echo "-----------------------------"
if [ -f "/var/lib/oxidized/.config/oxidized/config" ]; then
    echo "✅ Configuración principal: OK"
else
    echo "❌ Configuración principal: FALTA"
fi

if [ -f "/var/lib/oxidized/.config/oxidized/router.db" ]; then
    EQUIPOS=$(grep -v "^#" /var/lib/oxidized/.config/oxidized/router.db | grep -v "^$" | wc -l)
    echo "✅ Base de datos de equipos: OK ($EQUIPOS equipos configurados)"
else
    echo "❌ Base de datos de equipos: FALTA"
fi
echo

# Verificar repositorio Git
echo "📦 Repositorio Git de backups:"
echo "-----------------------------"
if [ -d "/var/lib/oxidized/oxidized.git" ]; then
    echo "✅ Repositorio Git: Inicializado"
    cd /var/lib/oxidized/oxidized.git
    COMMITS=$(git rev-list --all --count 2>/dev/null || echo "0")
    echo "📊 Total de commits: $COMMITS"
    if [ "$COMMITS" -gt "0" ]; then
        echo "📅 Último backup: $(git log -1 --format="%cd" --date=format:"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "No disponible")"
    fi
else
    echo "❌ Repositorio Git: NO ENCONTRADO"
fi
echo

# Verificar conectividad API
echo "🌐 API REST de Oxidized:"
echo "------------------------"
if curl -s http://localhost:8888/ >/dev/null 2>&1; then
    echo "✅ API REST (puerto 8888): ACCESIBLE"
    NODES=$(curl -s http://localhost:8888/nodes | wc -l 2>/dev/null || echo "0")
    echo "📊 Equipos en API: $NODES"
else
    echo "❌ API REST (puerto 8888): NO ACCESIBLE"
fi
echo

# Verificar logs recientes
echo "📝 Logs recientes (últimas 5 líneas):"
echo "------------------------------------"
if systemctl is-active oxidized >/dev/null; then
    journalctl -u oxidized --no-pager -n 5 --since "1 hour ago" || echo "❌ No se pudieron obtener los logs"
else
    echo "ℹ️  Servicio no está ejecutándose"
fi
echo

# Verificar uso de recursos
echo "💻 Uso de recursos:"
echo "------------------"
if pgrep -f oxidized >/dev/null; then
    PID=$(pgrep -f oxidized)
    CPU=$(ps -p $PID -o %cpu --no-headers 2>/dev/null || echo "N/A")
    MEM=$(ps -p $PID -o %mem --no-headers 2>/dev/null || echo "N/A")
    echo "CPU: ${CPU}%"
    echo "Memoria: ${MEM}%"
else
    echo "❌ Proceso no encontrado"
fi
echo

echo "=========================================="
echo "✅ Verificación completada - $(date)"
echo "=========================================="
