# Rochy

Cuaderno de recuerdos en Flutter con fotos, videos, notas de voz y ubicaciones
guardadas en el dispositivo.

## Mover y cambiar el tamaño

Mantén presionada una tarjeta para abrir su lista vertical de acciones. El menú
elige el lado con espacio y se mantiene dentro de la parte visible de la pantalla.
Para moverla, mantén presionado y arrastra; solo un dedo puede controlar el
lienzo a la vez.

En **Cambiar tamaño** puedes elegir diez combinaciones: medio ancho o ancho
completo, con cinco alturas. La selección se guarda al instante. También puedes
arrastrar los bordes blancos o la esquina inferior; tocar la esquina abre el
selector de tamaños.

## Mapa real

- Mapa interactivo de **OpenStreetMap** con `flutter_map`: calles, zoom y pines
  en latitud/longitud reales, con atribución visible.
- Ubicación del dispositivo mediante GPS y permiso solicitado al usarlo.
- Busca un lugar o pega coordenadas decimales, por ejemplo `10.4236,-75.5512`.
- Toca cualquier punto para colocar y guardar un pin. La consulta del nombre de
  la dirección conserva las coordenadas exactas que elegiste.
- El botón de direcciones abre **Google Maps** con ese destino exacto. Google
  Maps calcula la ruta desde la ubicación que tenga disponible. Si no se puede
  abrir, puedes copiar el enlace.
- Los recuerdos de ejemplo incluidos en el cuaderno son datos de demostración
  en Cartagena; no representan tu ubicación GPS.

Las búsquedas de nombres y el mapa requieren Internet. Sin conexión puedes
seleccionar coordenadas y conservarlas aunque no se encuentre la dirección.
La caché de teselas no garantiza un mapa completo sin conexión.

## Ejecutar y comprobar

Requiere Flutter con Dart 3.3 o posterior y el SDK de la plataforma elegida.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`. La
configuración actual firma las compilaciones de prueba con la clave de debug;
configura tu firma de distribución antes de publicar en una tienda.

## Servicios cartográficos

Datos de [OpenStreetMap](https://www.openstreetmap.org/copyright), bajo ODbL.
Se respeta la caché HTTP de `flutter_map` y no se precargan mapas masivamente.
Consulta la [política de teselas](https://operations.osmfoundation.org/policies/tiles/).

El geocodificador es [Photon](https://github.com/komoot/photon), software libre
basado en OpenStreetMap. La instancia pública de Komoot es un servicio de
demostración sin garantía de disponibilidad: para un despliegue de gran escala,
usa una instancia propia. Las búsquedas tienen demora y caché para reducir
peticiones. Los nombres o coordenadas consultados se envían a ese servicio;
los cuadernos se guardan localmente.

Se pueden configurar proveedores alternativos al compilar:

```sh
flutter run --dart-define=GEOCODER_URL=https://tu-instancia-photon.example
flutter run --dart-define=MAP_TILE_URL=https://tu-servidor.example/{z}/{x}/{y}.png
```

Los enlaces siguen el formato universal de [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started), sin clave de API.

Las dependencias conservan sus respectivas licencias; usar OpenStreetMap no
otorga una licencia de código abierto a este proyecto.
