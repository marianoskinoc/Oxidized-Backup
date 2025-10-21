# 🌐 Configuración Web de Zabbix para Oxidized

## 📋 Pasos para visualizar Oxidized en Zabbix

### 1. 🔧 Importar Template

1. **Acceder a la interfaz web de Zabbix:**
   ```
   URL: http://192.168.60.216 (o tu IP de Zabbix)
   Usuario: Admin
   Password: [tu password]
   ```

2. **Navegar a Templates:**
   - Ve a `Configuration` → `Templates`
   - Haz clic en `Import` (botón arriba a la derecha)

3. **Importar el archivo XML:**
   - Haz clic en `Choose File` o `Browse`
   - Selecciona el archivo: `zabbix-template-oxidized.xml`
   - Marca la opción `Templates` en las rules
   - Haz clic en `Import`

### 2. 🖥️ Asignar Template al Host

1. **Ir a Hosts:**
   - Ve a `Configuration` → `Hosts`
   - Busca el host `zabbix` (servidor Zabbix)
   - Haz clic en el nombre del host

2. **Asignar Template:**
   - Ve a la pestaña `Templates`
   - En el campo `Link new templates`, busca: `Template Oxidized Backup System`
   - Selecciona el template y haz clic en `Add`
   - Haz clic en `Update` para guardar

### 3. 📊 Verificar Items

1. **Ver Items del Host:**
   - Ve a `Configuration` → `Hosts`
   - Haz clic en `Items` junto al host `zabbix`
   - Deberías ver los nuevos items de Oxidized:
     - ✅ `Oxidized Service Status`
     - ✅ `Oxidized Devices Count`
     - ✅ `Oxidized API Availability`
     - ✅ `Oxidized Last Backup Timestamp`
     - ✅ `Oxidized Backup Status`

2. **Probar Items:**
   - Haz clic en cualquier item de Oxidized
   - Ve a la pestaña `Latest data`
   - Deberías ver valores como:
     - Service Status: `1 (Up)`
     - Devices Count: `1`
     - API Availability: `0 (Down)` - Normal si API no está activa
     - Backup Status: `0 (No backups)` - Normal si no hay backups aún

### 4. 🚨 Configurar Alertas (Opcional)

1. **Ver Triggers:**
   - Ve a `Configuration` → `Hosts`
   - Haz clic en `Triggers` junto al host `zabbix`
   - Deberías ver los triggers:
     - 🔴 `Oxidized service is down` (HIGH)
     - 🟡 `Oxidized: No backups found` (WARNING)
     - 🟡 `Oxidized: Backup is outdated` (WARNING)
     - 🟠 `Oxidized API is not available` (AVERAGE)

2. **Configurar Actions (si deseas notificaciones):**
   - Ve a `Configuration` → `Actions` → `Trigger actions`
   - Crea una nueva action para triggers de Oxidized
   - Configura notificaciones por email/Telegram según necesites

### 5. 📈 Crear Dashboard

1. **Crear Dashboard Personalizado:**
   - Ve a `Monitoring` → `Dashboards`
   - Haz clic en `Create dashboard`
   - Nombre: `Oxidized Monitor`

2. **Agregar Widgets:**

   **Widget 1 - Estado de Servicios:**
   - Tipo: `Plain text`
   - Name: `Estado Oxidized`
   - Items: Selecciona `Oxidized Service Status`
   
   **Widget 2 - Métricas Generales:**
   - Tipo: `Item value`
   - Name: `Métricas Oxidized`
   - Items: 
     - `Oxidized Devices Count`
     - `Oxidized Backup Status`
   
   **Widget 3 - Gráfico de Actividad:**
   - Tipo: `Graph (classic)`
   - Name: `Actividad de Backups`
   - Items: `Oxidized Last Backup Timestamp`

3. **Guardar Dashboard:**
   - Haz clic en `Save changes`

### 6. 🔍 Monitoreo en Tiempo Real

1. **Latest Data:**
   - Ve a `Monitoring` → `Latest data`
   - Filtra por host: `zabbix`
   - Busca los items que contengan "Oxidized"
   - Aquí verás los valores en tiempo real

2. **Problems:**
   - Ve a `Monitoring` → `Problems`
   - Filtra por tag: `Application: Oxidized`
   - Aquí verás cualquier alerta activa de Oxidized

## 📱 Valores Esperados Iniciales

### Estados Normales:
- **Service Status**: `1 (Up)` ✅
- **Devices Count**: `1` ✅
- **API Availability**: `0 (Down)` ⚠️ *Normal - API no configurada aún*
- **Backup Status**: `0 (No backups)` ⚠️ *Normal - Aún no hay backups*
- **Last Backup**: `0` ⚠️ *Normal - Sin backups aún*

### Estados Después del Primer Backup:
- **Service Status**: `1 (Up)` ✅
- **Devices Count**: `1` ✅
- **API Availability**: `1 (Up)` ✅
- **Backup Status**: `1 (Recent backup)` ✅
- **Last Backup**: `[timestamp]` ✅

## 🎯 Próximos Pasos

1. ✅ **Template importado y asignado**
2. ✅ **Items monitoreando correctamente**
3. 🔄 **Resolver credenciales para primer backup**
4. 🔄 **Activar API REST de Oxidized**
5. 🔄 **Configurar notificaciones**
6. 🔄 **Ampliar a más dispositivos**

## 🚫 Troubleshooting

### Problema: Items no reciben datos
**Solución:**
```bash
# Verificar UserParameters
zabbix_get -s localhost -k oxidized.service.status

# Reiniciar agente si es necesario
systemctl restart zabbix-agent2
```

### Problema: Template no aparece
**Solución:**
- Verificar que el archivo XML esté bien formado
- Asegurar permisos de lectura del archivo
- Revisar logs de Zabbix: `/var/log/zabbix/zabbix_server.log`

### Problema: Triggers no se activan
**Solución:**
- Verificar expresiones de triggers
- Comprobar que los items tengan datos recientes
- Revisar configuración de triggers en el template

---

**Estado**: Lista para configuración web
**Archivo Template**: `Oxidized-Backup/configs/zabbix-template-oxidized.xml`
**Próximo paso**: Importar template en interfaz web de Zabbix
