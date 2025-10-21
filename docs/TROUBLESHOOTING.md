# Solución de Problemas Oxidized

## 🚨 Problemas Comunes y Soluciones

### 1. Servicio Oxidized No Inicia

#### Síntomas
```bash
$ systemctl status oxidized
● oxidized.service - Oxidized Network Device Configuration Backup Tool
   Loaded: loaded (/etc/systemd/system/oxidized.service; enabled; vendor preset: enabled)
   Active: failed (Result: exit-code)
```

#### Diagnóstico
```bash
# Verificar logs detallados
journalctl -u oxidized -f --no-pager

# Verificar configuración
sudo -u oxidized oxidized --dry-run

# Verificar permisos
ls -la /var/lib/oxidized/.config/oxidized/
```

#### Soluciones
```bash
# 1. Corregir permisos
sudo chown -R oxidized:oxidized /var/lib/oxidized/
sudo chmod 755 /var/lib/oxidized/
sudo chmod 644 /var/lib/oxidized/.config/oxidized/*

# 2. Verificar sintaxis YAML
ruby -ryaml -e "YAML.load_file('/var/lib/oxidized/.config/oxidized/config')"

# 3. Reinstalar dependencias
sudo gem install oxidized --force
```

---

### 2. Error de Autenticación SSH

#### Síntomas
```
oxidized[1234]: msg: lib/oxidized/nodes.rb:126:in `rescue in connect': 
SSH connection failed: Net::SSH::AuthenticationFailed
```

#### Diagnóstico
```bash
# Probar conexión manual
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no usuario@dispositivo

# Verificar formato de credenciales
cat /var/lib/oxidized/.config/oxidized/router.db | grep -v "^#"

# Test de conectividad
nc -zv dispositivo_ip 22
```

#### Soluciones
```bash
# 1. Verificar credenciales en router.db
# Formato correcto: nombre:ip:modelo:usuario:contraseña:enable

# 2. Caracteres especiales en contraseñas
# Escapar caracteres especiales o usar comillas
dispositivo:192.168.1.1:routeros:admin:"password!@#$":

# 3. Configurar SSH en dispositivo
# MikroTik: /ip service set ssh port=22
# Cisco: ip ssh version 2
```

---

### 3. API Web No Responde

#### Síntomas
- Puerto 8888 no accesible
- Error "Connection refused"
- Interfaz web no carga

#### Diagnóstico
```bash
# Verificar puerto en uso
netstat -tlnp | grep 8888
ss -tlnp | grep 8888

# Verificar proceso Oxidized
ps aux | grep oxidized

# Test local
curl -v http://127.0.0.1:8888
```

#### Soluciones
```bash
# 1. Verificar configuración web
grep -A5 "rest:\|web:" /var/lib/oxidized/.config/oxidized/config

# 2. Configuración correcta
rest: 0.0.0.0:8888
web: 0.0.0.0:8888

# 3. Verificar firewall
sudo ufw status
sudo ufw allow 8888/tcp

# 4. Reiniciar servicio
sudo systemctl restart oxidized
```

---

### 4. Repositorio Git Corrupto

#### Síntomas
```
fatal: not a git repository
error: unable to write sha1 filename
```

#### Diagnóstico
```bash
# Verificar estado del repositorio
sudo -u oxidized git --git-dir=/var/lib/oxidized/oxidized.git status

# Verificar integridad
sudo -u oxidized git --git-dir=/var/lib/oxidized/oxidized.git fsck
```

#### Soluciones
```bash
# 1. Backup configuraciones existentes (si las hay)
sudo cp -r /var/lib/oxidized/oxidized.git /var/lib/oxidized/oxidized.git.backup

# 2. Recrear repositorio
sudo rm -rf /var/lib/oxidized/oxidized.git
sudo -u oxidized git init --bare /var/lib/oxidized/oxidized.git

# 3. Verificar permisos
sudo chown -R oxidized:oxidized /var/lib/oxidized/oxidized.git

# 4. Reiniciar servicio
sudo systemctl restart oxidized
```

---

### 5. Timeout en Conexiones

#### Síntomas
```
msg: lib/oxidized/worker.rb:73:in `rescue in work': 
Timeout::Error for device: dispositivo
```

#### Diagnóstico
```bash
# Verificar latencia de red
ping -c 5 dispositivo_ip

# Test de conectividad SSH
time ssh -o ConnectTimeout=30 usuario@dispositivo exit

# Verificar configuración timeout
grep -i timeout /var/lib/oxidized/.config/oxidized/config
```

#### Soluciones
```bash
# 1. Aumentar timeouts en config
timeout: 30
retries: 5

input:
  ssh:
    timeout: 45

# 2. Configurar SSH keepalive
input:
  ssh:
    keepalive: true
    keepalive_interval: 60

# 3. Reducir hilos simultáneos
threads: 10
```

---

### 6. Problemas de Memoria

#### Síntomas
- Oxidized consume mucha RAM
- Sistema se vuelve lento
- OOM Killer mata el proceso

#### Diagnóstico
```bash
# Verificar uso de memoria
ps aux | grep oxidized
free -h
top -p $(pgrep oxidized)

# Verificar logs del sistema
journalctl -u oxidized | grep -i memory
dmesg | grep -i "killed process"
```

#### Soluciones
```bash
# 1. Optimizar configuración
threads: 20          # Reducir hilos
interval: 7200       # Aumentar intervalo

# 2. Limpiar historial Git
cd /var/lib/oxidized/oxidized.git
sudo -u oxidized git gc --aggressive
sudo -u oxidized git prune

# 3. Configurar límites systemd
# Agregar a oxidized.service:
[Service]
MemoryLimit=512M
```

---

### 7. Dispositivos No Detectados

#### Síntomas
- Lista de dispositivos vacía
- No se realizan backups
- API muestra 0 dispositivos

#### Diagnóstico
```bash
# Verificar archivo de dispositivos
cat /var/lib/oxidized/.config/oxidized/router.db

# Verificar configuración source
grep -A10 "source:" /var/lib/oxidized/.config/oxidized/config

# Test manual de carga
sudo -u oxidized oxidized --dry-run
```

#### Soluciones
```bash
# 1. Verificar formato CSV
# Correcto: nombre:ip:modelo:usuario:contraseña:enable
# Incorrecto: nombre,ip,modelo,usuario,contraseña

# 2. Verificar permisos del archivo
sudo chmod 644 /var/lib/oxidized/.config/oxidized/router.db
sudo chown oxidized:oxidized /var/lib/oxidized/.config/oxidized/router.db

# 3. Verificar configuración source
source:
  default: csv
  csv:
    file: /var/lib/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /:/
```

---

### 8. Problemas con Modelos de Dispositivos

#### Síntomas
```
msg: lib/oxidized/model/model.rb:55:in `load': 
no such model: unknown_model
```

#### Diagnóstico
```bash
# Verificar modelos disponibles
sudo -u oxidized oxidized --debug | grep -i model

# Verificar mapeo de modelos
grep -A10 "model_map:" /var/lib/oxidized/.config/oxidized/config
```

#### Soluciones
```bash
# 1. Actualizar model_map en config
model_map:
  cisco: ios
  mikrotik: routeros
  juniper: junos
  hp: procurve
  ubiquiti: airos

# 2. Verificar formato en router.db
# Usar nombres del model_map, no nombres de fabricante
dispositivo:ip:routeros:user:pass:  # ✓ Correcto
dispositivo:ip:mikrotik:user:pass:  # ✗ Incorrecto
```

---

### 9. UserParameters Zabbix No Funcionan

#### Síntomas
- zabbix_get devuelve error
- Items no reciben datos
- Scripts no ejecutan

#### Diagnóstico
```bash
# Test directo de scripts
/opt/zabbix/scripts/oxidized-service-status.sh

# Test con zabbix_get
zabbix_get -s 127.0.0.1 -k oxidized.service.status

# Verificar configuración
grep oxidized /etc/zabbix/zabbix_agent2.conf
```

#### Soluciones
```bash
# 1. Verificar permisos de scripts
sudo chmod +x /opt/zabbix/scripts/oxidized-*.sh

# 2. Verificar sintaxis UserParameters
# Formato correcto:
UserParameter=oxidized.service.status,/opt/zabbix/scripts/oxidized-service-status.sh

# 3. Reiniciar zabbix-agent
sudo systemctl restart zabbix-agent2

# 4. Verificar usuario zabbix puede ejecutar scripts
sudo -u zabbix /opt/zabbix/scripts/oxidized-service-status.sh
```

---

## 🔧 Herramientas de Diagnóstico

### Script de Diagnóstico Completo
```bash
#!/bin/bash
# /opt/oxidized/diagnostic.sh

echo "=== OXIDIZED DIAGNOSTIC TOOL ==="
echo "Fecha: $(date)"
echo

echo "1. Estado del Servicio:"
systemctl status oxidized --no-pager -l

echo -e "\n2. Procesos:"
ps aux | grep -E "(oxidized|ruby)" | grep -v grep

echo -e "\n3. Puertos:"
netstat -tlnp | grep -E "(8888|22)"

echo -e "\n4. Uso de Memoria:"
free -h

echo -e "\n5. Espacio en Disco:"
df -h /var/lib/oxidized/

echo -e "\n6. Archivos de Configuración:"
ls -la /var/lib/oxidized/.config/oxidized/

echo -e "\n7. Último Backup Git:"
sudo -u oxidized git --git-dir=/var/lib/oxidized/oxidized.git log --oneline -5 2>/dev/null || echo "No hay commits"

echo -e "\n8. Test de Conectividad:"
while IFS=':' read -r name ip model user pass enable; do
    if [[ $name =~ ^[^#] ]] && [[ -n "$name" ]]; then
        timeout 3 nc -z "$ip" 22 2>/dev/null && echo "✓ $name ($ip)" || echo "✗ $name ($ip)"
    fi
done < /var/lib/oxidized/.config/oxidized/router.db

echo -e "\n9. UserParameters Test:"
for param in service.status devices.count api.available backup.status; do
    result=$(zabbix_get -s 127.0.0.1 -k "oxidized.$param" 2>/dev/null)
    echo "oxidized.$param: $result"
done

echo -e "\nDiagnóstico completado."
```

### Logs Centralizados
```bash
# Ver todos los logs relacionados con Oxidized
sudo journalctl -u oxidized --since "1 hour ago" --no-pager

# Logs en tiempo real
sudo journalctl -u oxidized -f

# Logs con nivel de debug
sudo journalctl -u oxidized -p debug --since "10 minutes ago"
```

### Monitoreo Continuo
```bash
# Script para monitoreo continuo
#!/bin/bash
while true; do
    echo "$(date): Servicio: $(systemctl is-active oxidized), API: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888)"
    sleep 60
done
```

---

## 📞 Obtener Ayuda

### Información para el Soporte
```bash
# Generar reporte de sistema
cat << EOF > /tmp/oxidized-support-info.txt
Sistema: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Ruby: $(ruby --version)
Oxidized: $(gem list oxidized)
Zabbix Agent: $(zabbix_agent2 --version 2>&1 | head -1)

Configuración:
$(cat /var/lib/oxidized/.config/oxidized/config)

Dispositivos:
$(grep -v "^#" /var/lib/oxidized/.config/oxidized/router.db | wc -l) dispositivos configurados

Último error:
$(journalctl -u oxidized --since "1 hour ago" | grep -i error | tail -5)
EOF
```

### Canales de Soporte
- **GitHub Issues:** Para bugs y features
- **Documentación oficial:** [Oxidized Wiki](https://github.com/ytti/oxidized/wiki)
- **Comunidad Zabbix:** Para integración específica

### Información Útil para Reportes
1. Versión del sistema operativo
2. Versión de Ruby y Oxidized
3. Configuración completa (sin contraseñas)
4. Logs de error específicos
5. Pasos para reproducir el problema