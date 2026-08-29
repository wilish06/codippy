# Codippy 📮

App SwiftUI multiplataforma (iPhone, iPad, Mac) para buscar códigos postales.

## Qué hace

- **Búsqueda instantánea** por código postal (`28001`) o por ciudad (`Madrid`), con debounce.
- **Mapa** del resultado con MapKit y botón "Abrir en Mapas".
- **Selector de país** con banderas (~30 países vía la API gratuita de [Zippopotam](https://api.zippopotam.us)).
- **"¿Dónde estoy?"**: código postal de tu ubicación actual (CoreLocation + geocoder de Apple).
- **Historial y favoritos** persistidos con SwiftData.
- **Modo offline por país** con datasets CSV/TSV empaquetados en la app.

## Funciones con IA (on-device, sin red ni coste)

Usan el modelo de **Apple Foundation Models** (requiere Apple Intelligence activado); si no está disponible, degradan con elegancia:

- **Pegar dirección** ✨: pega cualquier texto desordenado (un email, un WhatsApp…) y la IA extrae calle, ciudad, código postal y país, y lanza la búsqueda. Sin IA, el texto aplanado va directo al geocoder de Apple.
- **Escanear dirección** 📷: cámara en vivo (VisionKit, iPhone/iPad) o una foto/captura (Vision OCR, todas las plataformas) de un sobre o etiqueta; el texto reconocido pasa por el mismo extractor de IA.
- **"Sobre esta zona"**: en la ficha de cada resultado, una descripción breve del lugar generada en el dispositivo (la tarjeta solo aparece si el modelo está disponible).

## Cómo funciona la búsqueda

`PostalRepository` decide la fuente según el país seleccionado:

1. Si hay un **dataset empaquetado** para ese país → búsqueda 100% offline (`BundledDatasetProvider`).
2. Si no, código postal → API de Zippopotam (`ZippopotamService`).
3. Si no, ciudad → geocoder de Apple (`GeocoderService`).

## Añadir un dataset offline (CSV/TSV)

1. Descarga el fichero del país en [GeoNames](https://download.geonames.org/export/zip/) (p. ej. `ES.zip`) y descomprímelo.
2. Renómbralo a `postalcodes_ES.tsv` (patrón: `postalcodes_<código ISO de 2 letras>.tsv`).
3. Cópialo en `codippy/Datasets/` — con los grupos sincronizados de Xcode se incluye solo en el bundle.

Al arrancar, la app lo detecta automáticamente: el país aparece marcado como **(offline)** en el selector y todas sus búsquedas (código y ciudad) dejan de usar la red. Vienen incluidos España (`postalcodes_ES.tsv`) y Andorra (`postalcodes_AD.tsv`).

Formatos aceptados (extensiones `.tsv`, `.csv` o `.txt`):

- **GeoNames** (separado por tabuladores, sin cabecera): las 12 columnas tal cual vienen en la descarga.
- **CSV simple** (separado por comas): `country,postal_code,place,state,latitude,longitude`.

Nota: el dataset se parsea y cachea en memoria la primera vez que se busca en ese país; con ficheros grandes (EE. UU. ~4 MB) esa primera búsqueda puede tardar un instante.
