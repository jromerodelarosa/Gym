# IronLog · tu registro de gimnasio

App web personal (PWA) para registrar tus entrenos y pesos. Funciona sin internet, guarda cada serie al instante y, si la conectas a Supabase (gratis), hace copia en la nube y sincroniza entre el móvil y el ordenador.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app entera (HTML + CSS + JS). |
| `sw.js` | Hace que funcione sin conexión. |
| `manifest.webmanifest` + `icons/` | Permiten instalarla en la pantalla de inicio. |
| `supabase.sql` | SQL **completo** (v1 + v2) para un proyecto nuevo de Supabase. |
| `supabase-v2.sql` | Solo lo **nuevo** de la v2 (si ya ejecutaste el SQL de la v1). |

> Sube **siempre la carpeta completa**. El navegador exige que el "service worker" (`sw.js`) y el manifiesto sean archivos aparte; todo el código de la app está en `index.html`.

---

## Cómo se protegen tus datos

1. **En el dispositivo primero.** Cada serie se guarda en el momento en la base de datos del navegador (IndexedDB). Si se cierra la app a mitad de sesión, al abrirla sigues donde lo dejaste. La app pide al navegador "almacenamiento persistente" para que no borre nada (lo ves en *Ajustes → Este dispositivo*).
2. **Cola de subida.** Cada cambio entra en una cola que se sube a Supabase en cuanto hay red. Sin conexión no se pierde nada: se queda esperando.
3. **Sin pisar datos nuevos.** Cada registro lleva su fecha de modificación (`updated_at`). Gana siempre el más reciente, y el servidor también lo comprueba: rechaza cualquier versión más vieja que la que ya tiene.
4. **Nada se borra de verdad.** Los borrados son lógicos (`deleted_at`) y todo se puede recuperar desde la **Papelera**. La base de datos ni siquiera deja borrar filas desde la app.
5. **Copias automáticas.** Cada día se guarda una instantánea completa en el dispositivo y otra en Supabase (se conservan las últimas 30 de cada). Además puedes **exportar/importar un JSON**, y la app te avisa si llevas más de 14 días sin descargar uno. Importar fusiona los datos sin duplicar.
6. **Siempre sabes el estado.** El indicador de la cabecera muestra *Sincronizado ✓*, *Pendiente de subir (X cambios)*, *Sin conexión*, *Solo local* o *Error*. Si lo tocas, vas a los detalles.

---

## Puesta en marcha (sin programar)

### Paso 1 · Crear el proyecto gratis en Supabase
1. Entra en **https://supabase.com** y pulsa **Start your project**. Regístrate (con GitHub o con email).
2. Pulsa **New project**.
   - *Name*: `ironlog` (o el que quieras).
   - *Database Password*: pulsa **Generate a password** y guárdala en algún sitio (la app no la necesita).
   - *Region*: la más cercana (por ejemplo, *West EU (Ireland)* o *Central EU (Frankfurt)*).
   - Plan: **Free**.
3. Pulsa **Create new project** y espera uno o dos minutos a que termine.

### Paso 2 · Pegar el SQL
1. En el menú de la izquierda, entra en **SQL Editor**.
2. Pulsa **New query** (o el **+**).
3. Abre el archivo `supabase.sql`, copia **todo** su contenido y pégalo en el editor. También puedes copiarlo desde la propia app: *Ajustes → Ver SQL de las tablas → Copiar SQL*, una vez publicada.
4. Pulsa **Run** (o Ctrl/Cmd + Enter). Debe salir *Success* y una tabla con `registros = 0`.

Esto crea dos tablas (`gym_records` y `gym_backups`) con **Row Level Security** activado: solo tu usuario puede leer y escribir tus datos.

### Paso 3 · Crear tu usuario (solo tú)
Lo más sencillo es crearlo desde Supabase:
1. Ve a **Authentication → Users → Add user → Create new user**.
2. Escribe tu email y una contraseña, marca **Auto Confirm User** y pulsa **Create user**.

Después, para que nadie más pueda registrarse, ve a **Authentication → Sign In / Providers** (en algunas versiones, *Authentication → Settings*) y desactiva **Allow new users to sign up**.

> También puedes usar el botón **Crear cuenta** de la app. En ese caso Supabase te enviará un email de confirmación (o desactiva *Confirm email* en *Authentication → Sign In / Providers → Email*). Cuando hayas creado tu cuenta, desactiva *Allow new users to sign up*.

### Paso 4 · Copiar la URL y la clave anon
1. En Supabase, ve a **Project Settings** (la rueda dentada) → **API** (o **Data API** / **API Keys**, según la versión).
2. Copia:
   - **Project URL**: algo como `https://abcdxyz.supabase.co`.
   - La clave **anon / public**: un texto largo que empieza por `eyJ…`. En los proyectos nuevos está en la pestaña **Legacy API Keys**. Si no la encuentras, la *Publishable key* (`sb_publishable_…`) también vale.
   - ⚠️ **Nunca** uses la clave `service_role` ni la *secret key*.
3. No hay que tocar el código: estos datos se pegan en la app (paso 6).

### Paso 5 · Publicar la web gratis
Tienes dos opciones. La A es la más rápida.

**Opción A · Netlify Drop (2 minutos)**
1. Entra en **https://app.netlify.com/drop**.
2. Arrastra **la carpeta entera** (la que contiene `index.html`, `sw.js`, `manifest.webmanifest`, `supabase.sql` y `icons/`) a la página.
3. En unos segundos te da una dirección del tipo `https://nombre-raro-123.netlify.app`. Para que no caduque, crea una cuenta gratis de Netlify cuando te lo pida y "reclama" el sitio. Desde *Site configuration → Change site name* puedes ponerle un nombre más fácil.
4. Para actualizar la app en el futuro: *Deploys* → arrastra de nuevo la carpeta.

**Opción B · GitHub Pages**
1. Sube estos archivos a un repositorio de GitHub (por ejemplo, este mismo), con `index.html` en la raíz.
2. En el repositorio: **Settings → Pages**.
3. En *Source* elige **Deploy from a branch**, selecciona la rama (por ejemplo `main`) y la carpeta `/ (root)`. Pulsa **Save**.
4. A los 1-2 minutos aparece la dirección: `https://TU-USUARIO.github.io/NOMBRE-DEL-REPO/`.

> La app **debe abrirse desde una dirección `https://`** (Netlify o GitHub Pages ya lo son). Si abres el archivo directamente con doble clic, funciona, pero no se puede instalar ni usar sin conexión.

### Paso 6 · Conectar la app con tu Supabase
1. Abre la dirección de tu web en el móvil.
2. Ve a **Ajustes → Nube · Supabase**.
3. Pega la **Project URL** y la **clave anon** y pulsa **Guardar configuración**.
4. Escribe tu email y contraseña y pulsa **Entrar**.
5. El indicador de arriba debe pasar a **Sincronizado ✓**.

En cada móvil u ordenador nuevo repites el paso 6: al entrar con tu cuenta se descargan todos tus datos.

### Paso 7 · Instalarla en la pantalla de inicio
- **iPhone (Safari):** botón **Compartir** (el cuadrado con la flecha) → **Añadir a pantalla de inicio** → **Añadir**.
- **Android (Chrome):** menú **⋮** → **Instalar aplicación** (o *Añadir a pantalla de inicio*).
- **Ordenador (Chrome/Edge):** icono de instalar en la barra de direcciones.

Después ve a *Ajustes → Este dispositivo* y comprueba que **Almacenamiento persistente** dice *✓ Concedido* (si no, pulsa *Solicitar*; con la app instalada el navegador suele concederlo).

---

## Novedades v2: motor de progresión, coach IA, perfil y fotos

### Motor de progresión (sin IA, exacto y verificable)
Calcula el peso y las reps con reglas fijas a partir de tus datos:
- **Subir peso:** tope del rango en todas las series con el RIR objetivo → +incremento del aparato (1, 2 o 2,5 kg; se cambia en cada ejercicio o en el editor de rutina). Si llegaste al tope pero al fallo (RIR 0) en un ejercicio pesado → "Consolida".
- **Mantener:** dentro del rango → mismo peso y +1 rep en la serie más floja.
- **Bajar 5-10 %:** por debajo del mínimo dos sesiones seguidas, o 1RM estimado un 5 % o más por debajo de tu mejor marca reciente.
- **Meseta:** 3 o más sesiones sin mejorar ni peso ni reps → aviso con opciones (descarga, cambiar rango, más descanso).
- Cada recomendación muestra el **porqué** con tus datos y un **nivel de confianza** según cuántas sesiones hay.

### Coach IA (Gemini, gratis)
- Pestaña **Coach**: tu objetivo, preguntas rápidas tras la sesión, alertas de patrones, propuestas de cambio, recomendaciones del próximo día, check-in semanal y chat.
- La IA recibe solo un **resumen compacto** (puedes verlo en Perfil → "Ver exactamente lo que recibe el coach"), usa respuestas cortas y caché, y hay un contador de peticiones de hoy.
- **Nada se cambia solo:** los cambios de rutina son propuestas que tú aceptas o rechazas (y se pueden deshacer).

### Paso A · Conseguir la API key gratuita de Gemini
1. Entra en **https://aistudio.google.com** con tu cuenta de Google y acepta las condiciones.
2. Pulsa **Get API key** (menú izquierdo o arriba a la derecha) y luego **Create API key**. Si te pregunta por un proyecto, elige el que te proponga o crea uno nuevo.
3. Copia la clave (empieza por `AIza…`). Es gratis; no hace falta poner tarjeta.
4. En la app: **Ajustes → Coach IA · Gemini**, pégala y pulsa **Guardar**. La app consulta los modelos disponibles y elige el **Flash más reciente** que admite imágenes. Si algún día Google retira ese modelo, cámbialo en el desplegable **Modelo** (o pulsa *Actualizar modelos*).
5. La clave se guarda en tu cuenta de Supabase (tabla privada `gym_secrets`) y en el dispositivo. Nunca en el código ni en las copias JSON. En un móvil nuevo, al entrar con tu cuenta, se descarga sola.

> El plan gratuito tiene un límite de peticiones por minuto y por día. Si se agota, la app lo avisa y todo lo demás (incluido el motor de reglas) sigue funcionando.

### Paso B · Ejecutar el SQL nuevo
1. Supabase → **SQL Editor** → **New query**.
2. Pega **todo** `supabase-v2.sql` (o en la app: *Ajustes → SQL nuevo (v2) → Copiar SQL*) y pulsa **Run**.
3. Al final debe salir una tabla con 7 filas: `gym_profile`, `gym_measurements`, `gym_photos`, `gym_checkins`, `gym_coach`, `gym_secrets` y `bucket: progress-photos`.

Qué crea: perfil y objetivo (`gym_profile`), medidas (`gym_measurements`), fotos (`gym_photos`, solo fecha y pose), preguntas y respuestas (`gym_checkins`), chat, propuestas y análisis del coach (`gym_coach`) y la clave (`gym_secrets`). Todas tienen **Row Level Security** (solo tu usuario), sin borrado real y con el guardián que nunca pisa datos más nuevos.

Si te saltas este paso, la app funciona igual, pero el indicador mostrará un error de sincronización hasta que lo ejecutes.

### Paso C · El bucket privado de fotos
El SQL del paso B **ya crea el bucket** `progress-photos` como privado, con sus permisos. Para comprobarlo: menú izquierdo → **Storage**. Debe aparecer `progress-photos` con la etiqueta *Private* (o sin la de *Public*).

Si no aparece (algunos proyectos no permiten crearlo por SQL), créalo a mano:
1. **Storage → New bucket**.
2. Nombre exacto: `progress-photos`.
3. Deja **Public bucket desactivado**.
4. Opcional: *Restrict file size* 5 MB y *Allowed MIME types* `image/jpeg`.
5. Pulsa **Create** y vuelve a ejecutar `supabase-v2.sql` para que se creen los permisos.

Las fotos se comprimen en el móvil (~1280 px, JPEG) antes de guardarse. Se quedan en el dispositivo y se suben a `TU-ID-DE-USUARIO/foto.jpg`: nadie más puede verlas. No van en las copias JSON porque pesan demasiado; su copia está en el bucket.

## Uso rápido

- **Hoy:** te propone el día que toca (1 → 2 → 3 → 1). Puedes elegir otro con los botones de abajo. Pulsa **Empezar**.
- El ejercicio que toca aparece arriba, destacado con la etiqueta **AHORA** y la tarjeta del **motor de progresión** (semáforo, peso exacto, porqué y confianza). Los siguientes salen más atenuados. Al completar todas sus series, el ejercicio se desliza a **Completados ✓** (abajo, en gris); tócalo para editarlo o desmárcalo para devolverlo arriba.
- Los campos vienen ya rellenos con lo de la última vez. Ajusta con **−2,5 / −1 / +1 / +2,5**, marca el RIR si quieres y pulsa **Guardar serie**. Arranca solo el descanso (2:30 en pesados y 1:15 en aislamientos; se cambia en Ajustes o por ejercicio) y al terminar vibra y suena.
- Si bates un récord (peso, 1RM estimado o volumen), sale la medalla con confeti.
- **Terminar sesión** muestra el resumen: duración, volumen, récords y comparación con la sesión anterior del mismo día.
- **Historial:** calendario coloreado por día, racha semanal, detalle editable de cada sesión y **Papelera**.
- **Progreso:** semana X de 10, series por grupo muscular, gráficas por ejercicio (peso máximo, 1RM y volumen), salón de récords y peso corporal.
- **Ajustes → Editar rutina y bloques:** añade, quita o reordena ejercicios; cambia series, reps, agarre y descanso. Un agarre distinto crea una variante con historial propio. **Nuevo bloque** copia la rutina actual (ideal para diciembre) y conserva todo lo anterior.

## Si algo va mal
- **"Faltan las tablas"**: no se ejecutó el SQL; repite el paso 2.
- **"Email o contraseña incorrectos" / "Email sin confirmar"**: revisa el paso 3 (marca *Auto Confirm User*).
- **"Pendiente de subir" que no baja**: comprueba la conexión y pulsa *Ajustes → Sincronizar ahora*. Mientras tanto, todo sigue guardado en el dispositivo.
- **Cambiar de móvil**: instala la app en el nuevo, haz el paso 6 y listo. Por si acaso, descarga antes un JSON desde *Ajustes → Exportar JSON*.
