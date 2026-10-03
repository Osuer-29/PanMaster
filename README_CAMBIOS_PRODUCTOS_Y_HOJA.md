# PanMaster — cambios solicitados

## Agregar/editar productos dentro de un módulo
El formulario de producto ahora muestra únicamente:
- Nombre del producto
- Unidad de medida (selección desde `units_of_measure`)
- Stock
- Notas

El módulo se asigna automáticamente al inventario desde el que se abrió el formulario. El guardado sigue completando en segundo plano los campos requeridos por el esquema existente (`sku`, `unit_id`, costo en cero si es nuevo, fecha de ingreso, tipo, estados activo, etc.). No se necesita cambiar el esquema SQL para simplificar el formulario.

## Hoja de salidas
- Lista los productos activos del inventario seleccionado o todos los inventarios.
- Columnas visibles: `Producto | Cantidad | Salida | Total`.
- `Cantidad` es la existencia actual, `Salida` es editable y `Total` calcula la existencia restante.
- `Guardar entradas/salidas` valida primero todas las cantidades y registra los movimientos en una sola petición a `inventory_movements`, evitando guardar solo una parte de la hoja si falla una fila.
- Después vuelve a consultar productos e historial desde Supabase y comprueba que el stock de cada producto haya bajado exactamente la cantidad registrada. Si no coincide, muestra una advertencia clara y pide revisar el trigger; no se debe volver a guardar la misma salida sin revisar el historial.
- `Imprimir hoja` imprime una hoja horizontal con bordes naranjas alrededor de la columna Salida.
- `Descargar Excel` descarga un archivo `.xls` que Excel puede abrir, con las cuatro columnas y bordes naranjas en Salida.

## Importante
El archivo `supabase/fix_inventory_movement_stock_trigger.sql` configura el trigger que descuenta el stock cuando se inserta un movimiento `manual_out`. Ejecútalo en Supabase SQL Editor si el trigger aún no está instalado o si la aplicación avisa que el movimiento se guardó pero el stock no cambió. Antes de repetir una salida, revisa el historial para evitar duplicarla.

No se pudo completar la compilación porque no se instalaron las dependencias en este entorno; la comprobación de TypeScript solo reportó módulos/dependencias ausentes, no errores de sintaxis en `App.tsx`. La conexión real con Supabase no se pudo probar desde aquí.

Conserva el `.env` local y haz una copia de seguridad antes de reemplazar archivos en tu proyecto actual. No ejecutes `schema.sql` ni `supabase_schema.sql` completos sobre una base de datos existente.
