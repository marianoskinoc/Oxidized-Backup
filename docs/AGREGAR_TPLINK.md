# Instrucciones: Añadir un equipo TP-Link a Oxidized

Fecha: 2025-10-30
Autor: (automatizado por sesión)

Resumen
-------
Este documento describe exactamente los pasos que ejecutamos para que Oxidized pueda conectarse por SSH a un switch TP-Link (IP 192.168.60.36), ejecutar `enable` y obtener correctamente la configuración con `show running-config`. También incluye instrucciones y ejemplos para agregar más equipos TP-Link al mismo grupo.

Requisitos previos
------------------
- Oxidized 0.34.3 (instalado en la VM) y oxidized-web activo (puerto 8888).
- Acceso a la VM con permisos para editar `/var/lib/oxidized/.config/oxidized/config` y reiniciar el servicio systemd `oxidized`.
- Usuario/contraseña para el dispositivo TP-Link (en nuestro caso: usuario `oxidized`, contraseña `2ECSx4u&kh+GyA5H`).
- El dispositivo TP-Link usa algoritmos SSH legacy (kex `diffie-hellman-group1-sha1`, host key `ssh-dss`, ciphers `aes*-cbc`, hmac `hmac-sha1`).

Resumen de cambios aplicados
----------------------------
1. En `config` runtime de Oxidized (ubicación actual usada en la VM):
   - Añadimos `groups.tplink-sw.input: ssh` (ya existía)
   - Añadimos variables SSH específicas que el plugin `input/ssh` entiende:
     - `ssh_kex: diffie-hellman-group1-sha1`
     - `ssh_encryption: aes128-cbc`
     - `ssh_host_key: ssh-dss`
     - `ssh_hmac: hmac-sha1`
   - Añadimos `enable: true` en `groups.tplink-sw.vars` para que Oxidized ejecute `enable` en `post_login`.
   - Temporalmente activamos `input.debug: true` para inspeccionar I/O y confirmar la sesión.

2. Parche en el modelo `tplink.rb` (gem local):
   - Se añadió lógica para intentar comandos alternativos si `show running-config` devuelve "Bad command" o "Error:". (Esta modificación es opcional en entornos donde `enable + show running-config` funciona.)

3. Reiniciamos el servicio `oxidized` y forzamos un fetch de la node usando la API web: `/node/fetch/tplink-sw/sd2_tpl_itPB`.

4. Verificamos el raw guardado desde la interfaz (o `curl` a la API) y confirmamos que la configuración completa fue guardada.

Archivos y rutas relevantes
--------------------------
- Config runtime de Oxidized (editada): `/var/lib/oxidized/.config/oxidized/config`
- Source CSV (router.db): `/var/lib/oxidized/.config/oxidized/router.db`
- Repo git donde Oxidized guarda configuraciones: `/var/lib/oxidized/oxidized.git`
- Modelo modificado (gem): `/var/lib/gems/3.1.0/gems/oxidized-0.34.3/lib/oxidized/model/tplink.rb`
- Oxidized web API: `http://127.0.0.1:8888`

Pasos detallados (lo que hicimos)
---------------------------------
1) Respaldar config actual (por si acaso):

```bash
cp /var/lib/oxidized/.config/oxidized/config /var/lib/oxidized/.config/oxidized/config.bak.$(date +%s)
```

2) Editar la configuración de Oxidized y añadir las vars para `tplink-sw` (ejemplo de bloque relevante):

```yaml
groups:
  tplink-sw:
    input: ssh
    vars:
      ssh_kex: diffie-hellman-group1-sha1
      ssh_encryption: aes128-cbc
      ssh_host_key: ssh-dss
      ssh_hmac: hmac-sha1
      enable: true
```

Notas:
- Es importante que las claves sean `ssh_kex`, `ssh_encryption`, `ssh_host_key`, `ssh_hmac` ya que el plugin `input/ssh` las mapea a opciones de `Net::SSH`.
- `enable: true` indica al modelo que, si está declarado en `cfg :ssh` con `post_login` que llame a `enable`, lo ejecute sin pedir contraseña. Si tu equipo pide contraseña para enable, en lugar de `true` deberías poner `enable: 'tu_contraseña'`.

3) (Temporal) activar debug I/O para comprobar la sesión (opcional, ruidoso):

```yaml
input:
  default: ssh
  debug: true
  ssh:
    secure: false
```

4) Reiniciar Oxidized para aplicar cambios:

```bash
systemctl restart oxidized
# esperar 1-2s y verificar logs
journalctl -u oxidized -n 200 --no-pager
```

5) Forzar fetch de la node para probar la captura inmediata:

```bash
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/sd2_tpl_itPB
# luego ver versiones o raw
curl -sS "http://127.0.0.1:8888/node/version?node_full=tplink-sw/sd2_tpl_itPB"
curl -sS "http://127.0.0.1:8888/node/fetch/tplink-sw/sd2_tpl_itPB"  # devuelve raw
```

6) Verificar raw: asegúrate de que empieza por cabecera (ej. `! System Location ...`) y termina en `end` o la forma que el modelo procesa.

7) Desactivar `input.debug` cuando confirmes que todo funciona para evitar logs verbosos y llenar disco:

```bash
# editar /var/lib/oxidized/.config/oxidized/config -> input.debug: false
systemctl restart oxidized
```

Cómo agregar más equipos TP-Link (paso a paso)
----------------------------------------------
1) Abrir `/var/lib/oxidized/.config/oxidized/router.db` y añadir una línea con el formato CSV que usa tu `source.csv` (en nuestro config:
   name:ip:model:username:password:group)

Ejemplo (añadir un nuevo switch TP-Link):

```
sd3_tpl_oficina:192.168.60.37:tplink:oxidized:2ECSx4u&kh+GyA5H:tplink-sw
```

Explicación columnas:
- name: identificador único (sin espacios)
- ip: dirección IP del equipo
- model: `tplink` (asegúrate que exista en `model_map` si es necesario)
- username/password: credenciales (pueden heredarse por grupo si están definidas en `groups`)
- group: `tplink-sw` para aplicar las mismas vars (ssh_kex, enable, etc.)

2) Opcional: añadir vars específicas por nodo (si la fuente o tu configuración lo permite) — por ejemplo si el `enable` requiere contraseña diferente:

- Si tu `source` soporta campos extras, puedes definir `vars` o editar `config` con `groups.<group>.models.tplink.<node>` según la prioridad que use Oxidized (node -> group model -> group -> model -> global).

3) Forzar fetch (prueba rápida):

```bash
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/sd3_tpl_oficina
```

4) Verificar raw y logs como en los pasos previos.

Notas sobre el model `tplink.rb` y persistencia
----------------------------------------------
- En esta sesión editamos el archivo dentro del gem instalado: `/var/lib/gems/3.1.0/gems/oxidized-0.34.3/lib/oxidized/model/tplink.rb`.
- Advertencia: futuras actualizaciones del gem `oxidized` pueden sobrescribir ese archivo. Para cambios permanentes y gestionables, lo ideal es:
  - Mantener un patch en control de versiones (por ejemplo en el repo donde guardas documentación) o
  - Implementar un modelo local personalizado y configurar Oxidized para cargar modelos desde un path local (ver documentación de Oxidized para `models_dir`).

Sugerencias de hardening y buenas prácticas
------------------------------------------
- Evita mantener `input.debug: true` en producción por tiempo prolongado.
- No edites gems directamente en sistemas críticos sin mantener un backup del patch.
- Si usas contraseñas en archivos de configuración, asegúrate de protegerlos con permisos restringidos (600) y gestionar secrets con herramientas adecuadas si es posible.

Troubleshooting rápido
----------------------
- Si ves "No suitable input found for <node>": revisa que `input` sea `ssh` y que el modelo tenga un bloque `cfg :ssh` definido.
- Si la negociación SSH falla por algoritmos, confirma los valores `ssh_kex`, `ssh_encryption`, `ssh_host_key`, `ssh_hmac` en `groups` o en el `node`.
- Si `show running-config` devuelve "Bad command":
  - Prueba manualmente en la VM con una sesión pty (`ssh -tt`) para ver qué comando sí devuelve la config. Si `enable` es necesario, asegúrate que Oxidized ejecute `enable` (var `enable: true` o `enable: 'password'`).
  - Considera añadir comandos alternativos en el `tplink.rb` si existen variantes de firmware.

Contacto y registro de cambios
------------------------------
- Cambios aplicados hoy:
  - `config` runtime: añadidas vars SSH, `enable: true`, y debug temporal.
  - `tplink.rb`: añadido fallback para comandos alternativos.
- Archivo de documentación creado: `/root/Proxmox/Oxidized-Backup/docs/AGREGAR_TPLINK.md`

Ejemplos "Try it" (ejecutar en la VM)
--------------------------------------
```bash
# Forzar fetch de un equipo (reemplazar nombre y grupo según router.db)
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/sd2_tpl_itPB

# Ver raw guardado
curl -sS http://127.0.0.1:8888/node/fetch/tplink-sw/sd2_tpl_itPB

# Reiniciar oxidized tras cambiar config
systemctl restart oxidized
journalctl -u oxidized -n 100 --no-pager
```

Fin del documento.
