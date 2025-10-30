# Variantes: cómo agregar TP-Link que no responden a 'enable + show running-config'

Fecha: 2025-10-30

Este documento complementa `AGREGAR_TPLINK.md` y cubre casos especiales que requieren pasos distintos al flujo estándar (enable + show running-config).

1) Caso A — El equipo pide contraseña en `enable`
------------------------------------------------
Síntoma: al ejecutar `enable` el dispositivo pide "Password:" y no acepta `enable: true`.

Solución:
- Si el `enable` pide contraseña, define en el grupo o en el nodo la variable `enable` con la contraseña:

  Ejemplo en `config`:

  ```yaml
  groups:
    tplink-sw:
      vars:
        enable: 'MiEnablePass'
  ```

  Oxidized, en el bloque `cfg :ssh` del modelo, soporta:
  - `enable: true` → ejecutar `enable` sin contraseña
  - `enable: 'pass'` → ejecutar `enable` y enviar la contraseña cuando se solicite

- Reinicia Oxidized y forzar fetch para validar.

2) Caso B — `show running-config` no existe y `enable` no cambia nada
---------------------------------------------------------------------
Síntoma: `show running-config` devuelve "Bad command" y `enable` no habilita el comando.

Solución:
- Identificar cuál comando sí devuelve la config conectándote manualmente (ssh -tt):

  ```bash
  ssh -tt -oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-dss -oCiphers=+aes128-cbc oxidized@IP
  enable
  # probar:
  show configuration
  show config
  display current-configuration
  show startup-config
  ```

- Una vez identificado el comando correcto, hay dos opciones:
  a) Añadir lógica al modelo `tplink.rb` para intentar comandos alternativos (como hicimos en la sesión). Esto requiere editar el modelo dentro del gem o, preferible, crear un modelo local.
  b) Si quieres una solución más mantenible, crear un modelo local en un directorio y apuntar Oxidized a ese `models_dir`.

Ejemplo (añadir comando alternativo en el modelo local):

```ruby
cmd 'show running-config' do |cfg|
  if cfg =~ /Bad command|Error:/i
    cmd = @input.cmd('show config')
    cfg = cmd if cmd && cmd !~ /Bad command|Error:/i
  end
  # procesar cfg
end
```

3) Caso C — El servidor SSH no negocia con Net::SSH por algoritmos muy limitados
---------------------------------------------------------------------------------
Síntoma: Net::SSH falla en la negociación; en logs aparece "Unable to negotiate".

Solución:
- Añadir en el `groups.tplink-sw.vars` las variables que mapean a `Net::SSH`:
  - `ssh_kex`, `ssh_encryption`, `ssh_host_key`, `ssh_hmac`.

Ejemplo:

```yaml
groups:
  tplink-sw:
    vars:
      ssh_kex: diffie-hellman-group1-sha1
      ssh_encryption: aes128-cbc
      ssh_host_key: ssh-dss
      ssh_hmac: hmac-sha1
```

- Reinicia Oxidized y vuelve a probar.

4) Caso D — El dispositivo cierra conexiones exec y solo responde en shell con pty
----------------------------------------------------------------------------------
Síntoma: comandos exec (`ssh host command`) fallan o la sesión se cierra; la única forma de obtener salida es interactiva.

Solución:
- Oxidized `input/ssh` ya usa pty y shell si `exec` no está activado. Asegúrate que `vars(:ssh_no_exec)` no esté forzado a true. Si la salida se cierra, prueba manualmente con `ssh -tt` para replicar la secuencia y luego adapta el modelo si necesita enviar secuencias especiales (ej. `send "\r"` o esperar prompts específicos con `expect` en el modelo).

5) Caso E — Múltiples variantes de firmware en la flota
------------------------------------------------------
Recomendación:
- Mantener un modelo base `tplink.rb` que implemente:
  - `post_login` con `enable` y envío de contraseña si es necesario
  - `cmd 'show running-config'` con fallback a una lista de comandos
  - `cmd :all` para normalizar line endings y quitar paginación

- Para modelos específicos por firmware, crea modelos locales con sufijos (ej. `tplink_v3.rb`) y mapea en `model_map` o en `groups.<group>.models` para usar el modelo correcto cuando corresponda.

6) Mantener cambios frente a actualizaciones del gem
----------------------------------------------------
- No edites directamente el gem si quieres que los cambios sean permanentes sin ser sobrescritos.
- Mejor práctica:
  - Crear `models_dir` local y colocar allí `tplink.rb` personalizado.
  - En `config` de Oxidized indicar `models_dir: /etc/oxidized/models` (o ruta elegida).

7) Checklist de verificación tras agregar un equipo variante
-----------------------------------------------------------
- [ ] Añadiste la línea en `router.db` con formato correcto
- [ ] Si el equipo necesita `enable` con contraseña, añadiste `enable: 'pass'` en vars del group o node
- [ ] Si SSH requiere algoritmos legacy, añadiste las `ssh_*` vars
- [ ] Reiniciaste Oxidized
- [ ] Forzaste fetch y revisaste el raw

8) Ejemplo rápido (node que necesita enable con contraseña diferente):

En `router.db` añade la línea:

```
sd-new:192.168.60.38:tplink:oxidized:2ECSx4u&kh+GyA5H:tplink-sw
```

Y en `config` si deseas especificar enable distinto para ese equipo (opcional):

```yaml
# en groups.tplink-sw.models.tplink.sd-new (si tu config lo soporta) o en nodo directo
# si tu source no soporta columnas extras, puedes usar groups per-node model override
```

Fin.
