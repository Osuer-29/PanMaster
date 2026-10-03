CAMBIOS SOLICITADOS — PANADERÍA INVENTORY

RECETAS
- El formulario de receta queda con nombre, ingredientes y una nota opcional de preparación.
- Se quitan categoría, rendimiento/unidad, tiempo de preparación y temperatura.
- El Word contiene solamente nombre e ingredientes; la sección PREPARATION aparece únicamente si se escribió una nota.
- No se muestra “Ficha técnica”.

ETIQUETAS PERSONALIZADAS DE EMPLEADOS
- La creación de etiquetas está visible solo para empleados.
- El administrador ve las etiquetas creadas por empleados en una lista separada y puede imprimirlas o eliminarlas.
- El botón Print permanece disponible para cada etiqueta guardada.

IMPORTANTE — SOLUCIONAR “TABLE NOT FOUND”
La tabla de Supabase no puede crearse desde el navegador de forma segura. Antes de guardar etiquetas:
1. Abre tu proyecto en Supabase.
2. Entra en SQL Editor y crea una consulta nueva.
3. Abre el archivo supabase/employee_custom_labels.sql de este proyecto y copia TODO su contenido.
4. Pégalo en SQL Editor y pulsa Run.
5. Recarga Panadería Inventory e inicia sesión como empleado para probar crear e imprimir una etiqueta.

El SQL crea la tabla y las políticas RLS. También hace opcional product_id en recipes si esa columna existe, para que el formulario simplificado no necesite pedir un producto relacionado.
No ejecutes schema.sql completo sobre la base de datos existente.
