# Codippy 📮

App SwiftUI para iPhone y iPad para buscar códigos postales.

## Qué hace

- **Búsqueda instantánea** por código postal (`28001`) o por ciudad (`Madrid`), con debounce.
- **Mapa** del resultado con MapKit y botón "Abrir en Mapas".
- **Selector de país** con banderas (~30 países vía la API gratuita de [Zippopotam](https://api.zippopotam.us)).
- **"¿Dónde estoy?"**: código postal de tu ubicación actual (CoreLocation + geocoder de Apple).
- **Historial y favoritos** persistidos con SwiftData.
- **Modo offline por país**: España y Andorra van dentro de la app; otros 31 países se pueden descargar desde "Países sin conexión…" (datasets de GeoNames comprimidos, servidos desde `docs/datasets/`).
- **Provincia** en cada resultado (además de la región) y **códigos cercanos** en el mapa y en lista, con su distancia.
- **Distancia desde tu ubicación** en los resultados, si has dado permiso.
- **Validación del formato** del código por país: avisa si el código está incompleto o no puede existir en ese país, sin gastar una consulta.
- **Compartir y copiar la dirección completa** desde la ficha.
- **Interfaz en español e inglés** (catálogos de cadenas en `Localizable.xcstrings`).

## Integraciones con el sistema

- **Esquema de URL** `codippy://`: `codippy://search?q=28001&country=ES`, `codippy://smart?text=…` (texto libre con una dirección) y `codippy://locate`.
- **Atajos y Siri** (App Intents): "Buscar en Codippy", "Obtener código postal" (devuelve el código como texto, sin abrir la app) y "Mi código postal".
- **Widgets** (target `CodippyWidgets`): "Mi código postal" (ubicación actual; tamaños pequeño, mediano y de pantalla bloqueada) y "Favoritos" (los favoritos se publican en el App Group `group.com.wilish.codippy` vía `FavoritesSync`).
- **Extensión de compartir** (target `CodippyShare`): selecciona una dirección en cualquier app → Compartir → Codippy; muestra los códigos ahí mismo y permite abrir la app.

## Funciones con IA (on-device, sin red ni coste)

Usan el modelo de **Apple Foundation Models** (requiere Apple Intelligence activado); si no está disponible, degradan con elegancia:

- **Pegar dirección** ✨: pega cualquier texto desordenado (un email, un WhatsApp…) y la IA extrae calle, ciudad, código postal y país, y lanza la búsqueda. Sin IA, el texto aplanado va directo al geocoder de Apple.
- **Escanear dirección** 📷: cámara en vivo (VisionKit) o una foto/captura (Vision OCR) de un sobre o etiqueta; el texto reconocido pasa por el mismo extractor de IA.

## Cómo funciona la búsqueda

`PostalRepository` decide la fuente según el país seleccionado:

1. Si hay un **dataset empaquetado** para ese país → búsqueda 100% offline (`BundledDatasetProvider`).
2. Si no, código postal → API de Zippopotam (`ZippopotamService`).
3. Si no, ciudad → geocoder de Apple (`GeocoderService`).

## Estructura

- `codippy/`: app (vistas, intents, catálogos de cadenas).
- `Shared/`: modelos, servicios y tema, compilados también en las extensiones.
- `CodippyShare/`, `CodippyWidgets/`: extensiones.
- `docs/`: web (GitHub Pages) con soporte, privacidad y `datasets/` (manifiesto + TSV comprimidos para la descarga offline).

## Añadir un dataset offline (CSV/TSV)

1. Descarga el fichero del país en [GeoNames](https://download.geonames.org/export/zip/) (p. ej. `ES.zip`) y descomprímelo.
2. Renómbralo a `postalcodes_ES.tsv` (patrón: `postalcodes_<código ISO de 2 letras>.tsv`).
3. Cópialo en `codippy/Datasets/` — con los grupos sincronizados de Xcode se incluye solo en el bundle.

Al arrancar, la app lo detecta automáticamente: el país aparece marcado como **(offline)** en el selector y todas sus búsquedas (código y ciudad) dejan de usar la red. Vienen incluidos España (`postalcodes_ES.tsv`) y Andorra (`postalcodes_AD.tsv`).

Formatos aceptados (extensiones `.tsv`, `.csv` o `.txt`):

- **GeoNames** (separado por tabuladores, sin cabecera): las 12 columnas tal cual vienen en la descarga.
- **CSV simple** (separado por comas): `country,postal_code,place,state,latitude,longitude`.

Nota: el dataset se parsea y cachea en memoria la primera vez que se busca en ese país; con ficheros grandes (EE. UU. ~4 MB) esa primera búsqueda puede tardar un instante.

### Publicar datasets descargables

`docs/datasets/manifest.json` lista los países disponibles (`code`, `url`, `bytes`, `records`, `updated`) y cada `postalcodes_<ISO2>.tsv.gz` es el fichero de GeoNames comprimido con `gzip -n`. Para actualizar: descarga los `.zip` de GeoNames, comprime los `.txt` y regenera el manifiesto; la app los descarga desde la URL de GitHub Pages y los guarda en Application Support/Datasets.
