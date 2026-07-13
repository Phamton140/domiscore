# DomiScore

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.6-blue.svg?style=flat-square&logo=flutter" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Dart-3.12.2-blue.svg?style=flat-square&logo=dart" alt="Dart Version" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg?style=flat-square" alt="Platform Support" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat-square" alt="License" />
</p>

**DomiScore** es la aplicación móvil definitiva para llevar el control y anotar las puntuaciones en tus partidas de dominó. Diseñada con una estética premium, limpia (Light Mode) y altamente legible, permite a todos los jugadores visualizar los totales de la partida incluso desde cierta distancia.

---

## 🚀 Características Clave

* **🎨 Diseño Premium e Intuitivo (Light Mode)**: Interfaz de usuario limpia sobre fondo gris claro, destacando las puntuaciones con gradientes de excelente calidad (Azul para *Nosotros* y Rojo para *Ellos*).
* **👁️ Máxima Legibilidad**: Números gigantescos en pantalla para que cualquiera en la mesa de juego pueda observar cómo va el puntaje de un solo vistazo.
* **💾 Persistencia Local**: Tus partidas no se perderán. Todo el historial de manos, victorias por bando, nombres de equipos y la meta configurada se guardan automáticamente con `shared_preferences`.
* **✏️ Personalización de Nombres**: Edita el nombre de ambos bandos de manera ágil (hasta 13 caracteres de límite) tocando cualquier parte de su cabecera. Cuenta con protección contra desbordamiento en la interfaz.
* **🎯 Control de Meta de Puntos**: Define los puntos necesarios para ganar (por defecto **200 pts**) a través de un diálogo cómodo con teclado numérico automático.
* **📳 Alerta de Victoria y Auto-Cierre**: Al alcanzar o sobrepasar la meta de puntos, el dispositivo móvil ejecuta una vibración física controlada durante **3 segundos** acompañada de una pantalla de felicitación interactiva. Inmediatamente termina la vibración, **la pantalla de victoria se cierra sola automáticamente**, actualizando el marcador principal en segundo plano sin requerir toques manuales.
* **⏳ Historial de Partida Anterior (Restauración)**:
  - Un nuevo botón de reloj (`Icons.history`) en la esquina superior izquierda de la cabecera permite visualizar los detalles de la partida que acaba de concluir.
  - **Función de Restauración**: Si se detecta que la partida terminó debido a una puntuación ingresada por error, el usuario puede presionar **RESTAURAR** en el historial. Esto devolverá de forma automática los puntos al tablero activo y **descontará la victoria** del equipo ganador, permitiendo tachar el puntaje incorrecto y continuar jugando sin alterar el historial acumulado.
* **🔄 Historial Inteligente de Manos**:
  - Ordenado de la mano más reciente a la más antigua.
  - Al ingresar puntos en un bando, se anota automáticamente un cero en el bando contrario.
  - Permite tachar un registro erróneo con una **línea de tachado que cruza toda la fila**, actualizando el total en tiempo real.
  - Posibilidad de deshacer o restaurar la mano eliminada instantáneamente pulsando el botón verde de restauración.
* **💸 Monetización Limpia**: Espacio fijo reservado para anuncios **Google AdMob** (Banner de 320x50) en el extremo inferior de la pantalla, completamente integrado sin invadir el espacio interactivo del juego ni sufrir desbordamientos por la apertura del teclado.

---

## 🛠️ Requisitos de Instalación

Para compilar y ejecutar este proyecto de manera local, asegúrate de tener instalado el entorno de desarrollo de Flutter:

* **Flutter SDK**: `>= 3.44.6`
* **Dart SDK**: `>= 3.12.2`
* **Android SDK** (con depuración USB habilitada en tu dispositivo físico) o **Xcode** (para desarrollo en iOS).

---

## 📦 Ejecución del Proyecto

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/Phamton140/domiscore.git
   cd domiscore
   ```

2. **Obtener dependencias**:
   ```bash
   flutter pub get
   ```

3. **Ejecutar en tu dispositivo conectado**:
   ```bash
   flutter run
   ```

---

## 💻 Tecnologías Utilizadas

* **Framework**: Flutter (Dart)
* **Persistencia**: SharedPreferences (almacenamiento key-value local)
* **Feedback Háptico**: HapticFeedback de Flutter (alertas de vibración del sistema)

---

<p align="center">
  Desarrollado con ❤️ para los amantes del dominó.
</p>
