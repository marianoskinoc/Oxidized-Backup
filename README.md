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

Oxidized-Backup
===============

Este repositorio contiene documentación y modelos personalizados para Oxidized.

Archivos importantes
-------------------
- `docs/AGREGAR_TPLINK.md` - Guía paso a paso para añadir un TP-Link (onboarding).
- `docs/AGREGAR_TPLINK_VARIANTES.md` - Casos especiales y variantes.
- `models/tplink.rb` - Modelo TP-Link personalizado (versionado aquí para evitar sobrescrituras del gem).
- `CHANGES.md` - Registro de cambios aplicados.
- Runtime config de Oxidized en la VM: `/var/lib/oxidized/.config/oxidized/config` (ahora apunta a `models_dir: /root/Proxmox/Oxidized-Backup/models`).

Cómo agregar más equipos TP-Link rápidamente
-------------------------------------------
1) Decide un nombre para el equipo (sin espacios). Recomiendo usar el patrón `tplink-<ubicacion>-<unidad>` o `sd<loc>_tpl_<id>`; en este repo usamos `sd2_tpl_itPB`.

2) Añade una línea en el archivo runtime `router.db` usado por Oxidized (por defecto en `/var/lib/oxidized/.config/oxidized/router.db`) con el formato:

  `name:ip:model:username:password:group`

  Ejemplo:

  `sd3_tpl_oficina:192.168.60.37:tplink:oxidized:2ECSx4u&kh+GyA5H:tplink-sw`

  - `model` debe ser `tplink` (mapeado a `TPLink` en `config`)
  - `group` debe ser `tplink-sw` para heredar las variables (ssh_kex, enable, etc.)

3) Forzar fetch para probar inmediatamente:

```bash
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/<name>
```

4) Verificar raw:

```bash
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/<name>
```

Si la captura falla, revisar logs:

```bash
journalctl -u oxidized -n 200 --no-pager
```

Añadir múltiples IPs desde aquí
------------------------------
Si me compartís la lista de IPs (o nombres+IPs) puedo agregarlas yo al `router.db`, commitear los cambios en este repo y pushearlos a GitHub.

Información de credenciales
---------------------------
- Si todos los equipos usan el mismo `username` y `password`, los agrego con esos valores.
- Si algún equipo tiene `enable` con contraseña distinta, indicalo y lo pondré en `groups` o a nivel de nodo según prefieras.

Ejemplo de flujo (automatizado que puedo ejecutar por vos):
1. Añadir entradas a `/var/lib/oxidized/.config/oxidized/router.db`.
2. Forzar fetch de cada node para validar.
3. Commitear el `router.db` al repo (opcional) y pushear a GitHub.

Privacidad y seguridad
----------------------
- Las credenciales quedan en el config runtime y en `router.db` (si lo comiteas). Si vas a versionar `router.db` considera encriptar/ocultar contraseñas o mantener el archivo fuera del repo.

¿Querés que agregue las IPs ahora? Si es así, pegá la lista en el siguiente formato (una por línea):

`<name>:<ip>`

Por ejemplo:

`sd3_tpl_oficina:192.168.60.37`
`sd4_tpl_bodega:192.168.60.38`

Si preferís, solo pega las IPs y propongo nombres automáticos (por ejemplo `tplink-<último-octeto>`).
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
