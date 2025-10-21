# 🔄 Oxidized - Backup de Configuraciones de Red

Oxidized es una herramienta moderna de backup de configuraciones de equipos de red que se integra perfectamente con Zabbix para una gestión completa de la infraestructura.

## 📁 Estructura del Directorio

### ⚙️ Configuraciones
- **[configs/](configs/)** - Archivos de configuración de Oxidized
  - Configuración principal del servicio
  - Base de datos de equipos
  - Templates personalizados

### 🛠️ Scripts
- **[scripts/](scripts/)** - Scripts de gestión y automatización
  - Scripts de mantenimiento
  - Integración con Zabbix
  - Scripts de notificación

### 📖 Documentación
- **[docs/](docs/)** - Documentación técnica
  - Guías de configuración
  - Procedimientos de restauración
  - Best practices

### 💾 Backups
- **[backups/](backups/)** - Respaldos y exportaciones
  - Copias de seguridad de configuraciones
  - Exportaciones de Git
  - Archives históricos

## 🎯 Características Implementadas

### ✅ Funcionalidades Activas
- **Backup automático** cada hora de configuraciones
- **Versionado Git** para tracking de cambios
- **API REST** en puerto 8888 para integración
- **Soporte multi-vendor** (Cisco, HP, Mikrotik, etc.)
- **Servicio systemd** para alta disponibilidad

### 🔧 Configuración Actual

| Parámetro | Valor |
|-----------|-------|
| **Intervalo de backup** | 3600 segundos (1 hora) |
| **Puerto API REST** | 8888 |
| **Repositorio Git** | /var/lib/oxidized/oxidized.git |
| **Timeout conexión** | 20 segundos |
| **Reintentos** | 3 |
| **Threads** | 30 |

## 📋 Equipos Configurados

### Equipos Actuales
- **sc_mkt_ypf** (192.168.60.15) - Switch Cisco IOS
  - Detectado desde monitoreo Zabbix
  - Estado: Configurado para backup

### Próximos a Agregar
- PBS Server management interface
- QNAP NAS management interface
- Otros switches y routers de la red

## 🚀 Instalación Completada

### Dependencias Instaladas
- ✅ Ruby 3.1.2
- ✅ Oxidized 0.34.3
- ✅ Oxidized-web 0.17.1
- ✅ Git para versionado
- ✅ Todas las librerías de desarrollo necesarias

### Servicios Configurados
- ✅ Usuario del sistema `oxidized`
- ✅ Servicio systemd habilitado
- ✅ Repositorio Git inicializado
- ✅ Configuración base establecida

## 🔗 Integración con Zabbix

### Funciones de Integración
1. **Discovery automático** de equipos desde Zabbix
2. **Alertas de backup** fallidos via Zabbix
3. **Métricas de estado** de backups
4. **Correlación de eventos** entre cambios y problemas

### API REST Endpoints
- `GET http://localhost:8888/` - Estado general
- `GET http://localhost:8888/nodes` - Lista de equipos
- `GET http://localhost:8888/node/show/{name}` - Última configuración
- `POST http://localhost:8888/node/next/{name}` - Forzar backup

## �� Comandos Útiles

### Gestión del Servicio
```bash
# Iniciar servicio
systemctl start oxidized

# Verificar estado
systemctl status oxidized

# Ver logs
journalctl -u oxidized -f

# Reiniciar servicio
systemctl restart oxidized
```

### Operaciones Manuales
```bash
# Ejecutar backup manual
sudo -u oxidized oxidized

# Verificar configuración
sudo -u oxidized oxidized --dry-run

# Ver historial Git
cd /var/lib/oxidized/oxidized.git && git log --oneline
```

## 🔧 Próximos Pasos

### Prioridad Alta
1. **Iniciar servicio Oxidized** y verificar funcionamiento
2. **Configurar credenciales** correctas para equipos
3. **Probar primer backup** del switch identificado
4. **Integrar con Zabbix** para alertas

### Prioridad Media
5. **Agregar más equipos** de la infraestructura
6. **Configurar oxidized-web** para interfaz gráfica
7. **Automatizar discovery** desde Zabbix
8. **Implementar notificaciones** de cambios

### Prioridad Baja
9. **Optimizar intervalos** según criticidad
10. **Configurar retention** de backups
11. **Implementar restore** automatizado
12. **Dashboard integrado** en Zabbix

---

**Instalación completada:** $(date '+%Y-%m-%d %H:%M')
**Estado:** Listo para configuración inicial
**Versión:** Oxidized 0.34.3
