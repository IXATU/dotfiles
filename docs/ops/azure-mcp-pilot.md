# Azure MCP + ChatGPT Secure MCP Tunnel: piloto WSL2 opt-in

Receta pequeña para PC-IXATU-09, independiente de Desktop Commander. Ejecutar
manualmente desde el checkout; no se instala ni registra en Cursor/Codex,
Chezmoi o el MANIFEST global. `dotfiles-update` solo reporta versiones del piloto
si está presente. No requiere abrir Cursor.

## Preparación y preview

Provisionar por separado `az`, `uvx` y `~/.local/bin/tunnel-client`. No hay
instaladores, update checks ni login dentro de esta receta. Azure MCP se obtiene
con `uvx --from msmcp-azure==3.0.0`; el primer arranque puede descargar el paquete.
El tunnel-client existente no se actualiza: su versión y compatibilidad deben
verificarse manualmente en PC09 antes de activar.

Crear **un túnel y runtime key nuevos para PC09** en ChatGPT Secure MCP Tunnel.
No copiar ni reutilizar el ID, perfil, runtime.env o credenciales de PC08 sin
autorización explícita. El ID es identificador; la runtime key es un secreto
distinto. No pasar la clave por argumentos CLI, chat o archivos del repo.

```bash
bin/dotfiles-azure-mcp-pilot                 # resumen, sin escribir
bin/dotfiles-azure-mcp-pilot tunnel_REPLACE  # preview completa
bin/dotfiles-azure-mcp-pilot --apply tunnel_REPLACE
```

`--apply` crea únicamente los archivos ausentes que muestra la preview:

- `~/.local/share/ixatu-azure-mcp-pilot/start.sh` (0700)
- `~/.config/tunnel-client/ixatu-azure-mcp-pilot.yaml` (0600)
- `~/.config/systemd/user/ixatu-azure-mcp-pilot.service` (0600)

Repetir con el mismo ID conserva archivos idénticos; cualquier diferencia se
rechaza antes de escribir. No sobreescribe archivos ajenos ni credenciales,
ni inicia/recarga servicios. Rechaza symlinks en las rutas del piloto. HOME debe
ser absoluto y usar letras, dígitos, `_`, `.`, `/` o `-` (sin espacios ni `%`).

## Activación humana de la clave y del servicio

En una terminal Bash local, sin tracing (`set +x`), introducir la runtime key con
entrada oculta. Este bloque se niega a reemplazar un runtime.env existente;
si existe, conservarlo y revisar su procedencia manualmente. No ejecutar el
bloque sobre rutas con symlinks. No guardar la clave en historial ni capturas.

```bash
set +x
umask 077
mkdir -p "$HOME/.config/ixatu-azure-mcp-pilot"
read -r -s -p 'PC09 runtime key: ' pilot_key; printf '\n'
if [[ -n "$pilot_key" && "$pilot_key" =~ ^[A-Za-z0-9_./+=:-]+$ ]]; then
  (set -o noclobber
   printf 'AZURE_MCP_CONTROL_PLANE_API_KEY=%s\n' "$pilot_key" > "$HOME/.config/ixatu-azure-mcp-pilot/runtime.env")
else
  printf 'Clave vacía/formato inesperado; no se ha escrito.\n' >&2
fi
unset pilot_key
```

El archivo recién creado tiene modo 0600 por `umask 077`. El perfil referencia
`env:AZURE_MCP_CONTROL_PLANE_API_KEY`; systemd carga el archivo dedicado mediante
`EnvironmentFile=%h/.config/ixatu-azure-mcp-pilot/runtime.env`. No se usa SOPS ni
el entorno de Desktop Commander. No hacer `cat`, `source` o commit de ese archivo.

Antes de iniciar, comprobar manualmente la sesión CLI y sus permisos DEV en
PC09. Autenticación CLI ya preparada es prerrequisito; el script no ejecuta
`az login`, no cambia suscripciones y no consulta Azure. La identidad debe tener
acceso limitado a DEV: namespaces y `--read-only` **no son una frontera DEV/PROD**.
No activar con permisos PROD amplios.

```bash
systemctl --user daemon-reload
systemctl --user start ixatu-azure-mcp-pilot.service
bin/dotfiles-azure-mcp-pilot --doctor  # --status es alias; sin cambios
# Opcional, solo tras validar:
systemctl --user enable ixatu-azure-mcp-pilot.service
```

El doctor verifica herramientas, presencia de archivos, propietario/modo/tamaño
de runtime.env y HTTP en `127.0.0.1:49188/readyz`; nunca lee la clave ni invoca
Azure/uvx/tunnel-client. Sale distinto de cero si falta algo. Un HTTP OK no prueba
la autenticación Azure ni el catálogo MCP. Validar en ChatGPT que `tools/list`
contenga exactamente `containerapps_list`, `group_list`, `group_resource_list`,
y hacer una consulta DEV de lectura antes de dar por válido el piloto. La receta
reproduce `--transport stdio --mode all --namespace containerapps --namespace group
--read-only` de 3.0.0; no añadir namespaces ni operaciones. Si el catálogo difiere,
parar el piloto y revisar antes de usarlo.

## Diagnóstico y parada

### Versiones en dotfiles-update

La sección `tools` lee el pin de
`~/.local/share/ixatu-azure-mcp-pilot/start.sh` y consulta el JSON de PyPI para
`msmcp-azure` (con timeouts de conexión/total de 5/15 segundos). Solo considera
versiones finales `x.y.z` con archivos no retirados; ignora beta/rc/dev.
El snapshot incluye `Azure MCP` con el pin antes/después idéntico, incluso si
PyPI falla o se ejecuta otra sección. `PINNED` representa configuración, no una
comprobación de la versión cargada en un proceso vivo ni de la caché uvx.

Si aparece una estable posterior, emite `ACTIVATION_PENDING`: revisar manualmente
la compatibilidad, cambiar el pin del launcher dedicado y activar/reiniciar el
piloto en una terminal humana separada. El updater no descarga/ejecuta uvx, no
escribe el launcher ni modifica servicios, autenticación o túneles. `--apply`
de la receta seguirá rechazando un launcher con un pin distinto del generado.
Sin piloto: `SKIP`; sin versión remota válida: `WARN` y pin conservado. En mock
no hay consulta de red. Tunnel Client conserva su reporte separado existente.

### Operación local

PATH fijo en systemd y launcher: `$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin`.
Evita el 401 «Azure CLI not installed» cuando `az` viene de pipx en `.local/bin`.
Se fija `AZURE_TOKEN_CREDENTIALS=AzureCliCredential` para evitar intentos de broker
sin X/MSAL antes de CLI ([autenticación Microsoft](https://github.com/microsoft/mcp/blob/main/docs/Authentication.md)).
`AZURE_MCP_COLLECT_TELEMETRY=false` desactiva toda telemetría; también se desactiva
la de Microsoft explícitamente ([referencia Microsoft](https://github.com/microsoft/mcp/blob/main/servers/Azure.Mcp.Server/README.md)).

El perfil usa `log.level: warn` para evitar ruido de polling. Para depurar,
cambiar **solo el perfil local dedicado** a `debug`, reiniciar este servicio,
inspeccionar logs localmente y volver a `warn`. Los logs debug pueden contener
datos sensibles; no compartirlos sin revisión. `--apply` rechazará el perfil
modificado hasta restaurar su contenido original.

```bash
systemctl --user restart ixatu-azure-mcp-pilot.service
systemctl --user stop ixatu-azure-mcp-pilot.service
# Si se habilitó inicio automático:
systemctl --user disable ixatu-azure-mcp-pilot.service
```

No tocar servicios, perfiles ni puerto 49187 de Desktop Commander. Esta receta
no transfiere credenciales, crea recursos Azure ni valida remotamente producción.
