PANMASTER — NOTA DE SEGURIDAD DE BASE DE DATOS

La separación de productos por módulo utiliza la columna existente products.module_id. Esta corrección de interfaz no necesita una migración SQL si esa columna ya existe.

No ejecutes supabase/schema.sql ni supabase_schema.sql completos sobre una base que ya tiene tablas y enums de inventario: representan un esquema inicial/alternativo y no son migraciones seguras para todas las instalaciones existentes.

No borres migraciones aplicadas. Eliminar archivos localmente no revierte cambios ejecutados en Supabase. Antes de aplicar SQL a una base existente, revisa las migraciones y crea una copia de seguridad.

Nunca coloques la clave service_role en el frontend ni en el archivo .env usado por Vite.
