# Corrección de recetas, entradas/salidas y trazabilidad

## Activación en Supabase

Antes de utilizar esta versión, abre el SQL Editor de tu proyecto Supabase y ejecuta **únicamente**:

`supabase/migrations/20261004_recipes_stock_traceability.sql`

Es una migración transaccional. Conserva recetas, productos y movimientos anteriores; no recalcula stock histórico ni cambia los roles de los usuarios. Agrega columnas de trazabilidad, funciones de guardado y registro de auditoría. Reemplaza el trigger conocido de stock y la función anterior de eliminación por una anulación con reversión registrada. No desactiva RLS. Las operaciones de escritura requieren un perfil superadmin activo.

No vuelvas a ejecutar los scripts antiguos `schema.sql`, `supabase_schema.sql`, `fix_inventory_movement_stock_trigger.sql` o `delete_inventory_movement_reversibly.sql` después de esta migración: contienen versiones anteriores del trigger o de la reversión. Se conservan como parte del código y de su historial.

La migración se probó con el CHECK legado de entrada/salida/ajuste y con el enum moderno manual_in/manual_out/count_adjustment. Si tu base tiene otros triggers personalizados que también actualizan stock, revisa que no dupliquen el descuento. Puedes listar los triggers con:

```sql
SELECT t.tgname, pg_get_triggerdef(t.oid)
FROM pg_trigger t
WHERE t.tgrelid = 'public.inventory_movements'::regclass AND NOT t.tgisinternal;
```

Los movimientos históricos ya guardados sin descuento requieren conciliación con tus existencias reales. Esta versión no los descuenta automáticamente porque podría descontar dos veces movimientos que sí se aplicaron.

## Qué se corrigió

- **Save Recipe:** ya no envía la columna inexistente is_active. El servidor confirma el identificador guardado. Crear y editar mantienen los campos de relación y demás datos existentes. La nota es opcional. Los errores aparecen dentro de la ventana y los envíos simultáneos se bloquean.
- **Entradas/salidas:** puedes registrar ambas cantidades en la hoja. El servidor bloquea cada producto, calcula el saldo real y guarda el stock y todos los movimientos del lote dentro de la misma transacción. Una cantidad inválida o una salida insuficiente revierte el lote completo.
- **Reintentos:** el lote conserva su identificador incluso si se pierde la respuesta o se recarga la página. Repetirlo confirma la misma operación en lugar de volver a descontar. Cuando hay un lote pendiente, confírmalo con Guardar entradas/salidas antes de cambiar cantidades.
- **Trazabilidad:** cada nuevo movimiento guarda referencia, lote, usuario, fecha, producto/unidad/inventario y saldo anterior/posterior calculado en el servidor. Las modificaciones y eliminaciones también dejan un registro en panmaster_inventory_audit. Excel e impresión incorporan referencias y responsables.
- **Anulación:** el botón del historial revierte el stock mediante un nuevo movimiento relacionado y conserva el original marcado como anulado. No permite anular dos veces ni descontar la reversión de una entrada si sus existencias ya se consumieron.

## Abrir, editar y compilar

Extrae toda la carpeta y abre `index.html` para utilizar la compilación incluida. Mantén `publicacion/` junto a este archivo.

Para editar:

```powershell
npm ci
npm run dev
```

Después de editar:

```powershell
npm run build
```

La apertura por archivo local, las rutas relativas y la configuración anterior de Pages se conservan. Para publicar, consulta LEEME_GITHUB_PAGES.md; instala primero la migración para que las nuevas funciones de guardado estén disponibles.

## Pruebas realizadas y límites

La compilación TypeScript/Vite pasó. En PostgreSQL aislado se probaron creación/edición de recetas, conservación de relaciones, stock 10→7 al retirar 3, reintentos sin descuento adicional, rollback de lotes inválidos, anulación con auditoría, entrada y salida juntas, ajuste a cero, permisos y reinstalación sin alterar históricos. En Edge se probaron los botones, los errores dentro del modal y la recuperación de una respuesta perdida mediante Supabase simulado. Se conservó la apertura local y por HTTP.

No se ha ejecutado la migración en tu Supabase ni se ha probado tu sesión real. El SQL Editor requiere acceso propietario que no está disponible en esta sesión. El archivo incluido permite activar la corrección; no basta con reemplazar únicamente App.tsx.

Prueba reproducible de la base aislada (no conecta a Supabase):

```powershell
npm install --no-save --package-lock=false --ignore-scripts @electric-sql/pglite
node tests/database.mjs
```
