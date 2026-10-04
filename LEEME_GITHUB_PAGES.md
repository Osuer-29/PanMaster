# PanMaster completo: abrir, editar y publicar

## Abrir en tu computadora
Extrae todo el ZIP y haz doble clic en index.html dentro de PanMaster-completo. Conserva index.html junto a la carpeta publicacion/. No abras el HTML dentro del ZIP. La interfaz abre sin iniciar Vite; iniciar sesión requiere Internet y tu cuenta de Supabase.

## GitHub Pages desde una rama
1. Sube el contenido de PanMaster-completo a la raíz del repositorio. Incluye index.html, publicacion/ y .nojekyll. No subas el ZIP como un único archivo, ni node_modules o .env.
2. En Settings → Pages, selecciona Deploy from a branch, tu rama (por ejemplo main) y /(root).
3. Espera a que termine la publicación y abre su dirección. Usa Ctrl+F5 si ves una versión anterior.

Los archivos de publicacion/ ya están compilados con la configuración publicable de Supabase del proyecto recibido. Las rutas relativas permiten cargar desde la raíz o una subcarpeta. Después de editar el código o cambiar la configuración, compila nuevamente y sube publicacion/ e index.html actualizados.

## Alternativa: GitHub Actions
1. Sube todo el código a la raíz del repositorio, incluyendo .github/workflows/pages.yml.
2. En Settings → Secrets and variables → Actions → Variables, crea VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY con los valores de tu .env local.
3. En Settings → Pages → Source, selecciona GitHub Actions.
4. En Actions, ejecuta Publicar PanMaster en GitHub Pages → Run workflow. Los cambios posteriores en main o master también lo ejecutan.

El flujo comprueba TypeScript, compila y publica publicacion/. Si no hay variables de Actions, conserva los valores del .env que ya existe en este repositorio. Elige el procedimiento de la rama o Actions según el origen configurado en Pages.

## Editar y empaquetar
El código fuente completo está en src/; los archivos SQL y la función están en supabase/. app.html es la entrada de desarrollo. scripts/build.mjs genera index.html y publicacion/index.html.

```powershell
npm ci
npm run dev
```

Si el navegador no abre automáticamente, visita http://localhost:5173/app.html. El .env incluido conserva la configuración local del proyecto recibido; .gitignore evita subirlo a Git. Para usar otro proyecto de Supabase, modifica sus variables y recompila.

```powershell
npm run build
npm run preview
```

Después de compilar también puedes cerrar Vite y abrir index.html directamente. Para empaquetar, utiliza publicacion/ como entrada web y sigue las instrucciones de tu empaquetador. Esta entrega no incluye un instalador de escritorio.

## Qué se corrigió
La foto mostraba el HTML de desarrollo abierto como archivo local. Importaba /src/main.tsx, que el navegador no puede ejecutar directamente. Además, los módulos ES externos tienen restricciones bajo file://.

La compilación ahora genera JavaScript clásico en un único archivo, CSS y rutas relativas. Ambas entradas cargan la aplicación por doble clic y por HTTP. Si faltan los archivos compilados, se muestran instrucciones en lugar de una página vacía. Una URL inválida de Supabase muestra la configuración sin romper la importación de la app.

Verificado en Edge: ambas entradas por archivo local; HTTP en una subcarpeta simulando Pages; servidor de desarrollo; login visible; estilos; botón Crear cuenta con contraseña vacía; sin errores de ejecución. Compilación TypeScript y Vite correcta. No se inició sesión ni se modificaron datos. No se ha desplegado en tu cuenta de GitHub. No necesitas ejecutar SQL para corregir esta pantalla en blanco.

Referencia oficial: https://v6.vite.dev/guide/static-deploy#github-pages

