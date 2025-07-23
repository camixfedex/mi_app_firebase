import 'dart:async'; // Para manejar operaciones asíncronas como Future y TimeoutException
import 'package:flutter/material.dart'; // El framework UI de Flutter
import 'package:firebase_core/firebase_core.dart'; // Para inicializar Firebase en tu app
import 'package:firebase_auth/firebase_auth.dart'; // Para la autenticación de Firebase (anónima en este caso)
import 'package:http/http.dart' as http; // Para hacer solicitudes HTTP a tu API
import 'dart:convert'; // Para codificar y decodificar JSON

// --- Configuración Principal de la Aplicación ---
void main() async {
  // Asegura que los widgets de Flutter estén inicializados antes de usar Firebase.
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase para tu proyecto.
  await Firebase.initializeApp();
  // Inicia la aplicación Flutter ejecutando el widget raíz.
  runApp(const ApplicationRoot());
}

class ApplicationRoot extends StatelessWidget {
  const ApplicationRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo de Firebase y API', // Título de la aplicación
      debugShowCheckedModeBanner: false, // Oculta la etiqueta de "DEBUG" en la esquina
      theme: ThemeData(
        useMaterial3: true, // Habilita el diseño de Material Design 3
        colorSchemeSeed: Colors.blueAccent, // Define un color base para el tema
      ),
      home: const AuthenticationScreen(), // La pantalla inicial de la aplicación
    );
  }
}

// --- Enumeraciones para la Gestión de Estados ---
// Define los posibles estados de autenticación del usuario.
enum AuthStatus {
  initial, // Estado inicial, verificando si hay sesión
  signedIn, // Usuario ha iniciado sesión
  notSignedIn, // Usuario no ha iniciado sesión
  error, // Hubo un error en la autenticación
}

// Define los posibles estados de una solicitud a la API.
enum ApiRequestStatus {
  idle, // La solicitud no se ha iniciado
  loading, // La solicitud está en progreso
  success, // La solicitud fue exitosa
  failure, // La solicitud falló
  requiresAuth, // La solicitud requiere que el usuario esté autenticado
}

// --- Widget de la Pantalla de Autenticación ---
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  // Variable para el estado actual de la autenticación.
  AuthStatus _currentAuthStatus = AuthStatus.initial;
  // Variable para el estado actual de la solicitud a la API.
  ApiRequestStatus _currentApiStatus = ApiRequestStatus.idle;
  // Mensaje que se muestra al usuario sobre la API o errores.
  String _apiResponseMessage = '';
  // Objeto User de Firebase si hay una sesión activa.
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Escucha los cambios en el estado de autenticación de Firebase.
    // Esto permite que la UI se actualice automáticamente cuando el usuario inicia/cierra sesión.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user; // Actualiza el usuario actual
        if (user != null) {
          _currentAuthStatus = AuthStatus.signedIn; // Si hay usuario, está logeado
        } else {
          _currentAuthStatus = AuthStatus.notSignedIn; // Si no hay usuario, no está logeado
        }
        _apiResponseMessage = ''; // Limpia el mensaje de la API al cambiar el estado de auth.
      });
    });
  }

  // --- Métodos de Autenticación ---

  // Maneja el inicio de sesión anónimo.
  Future<void> _handleAnonymousSignIn() async {
    // Si el usuario ya está autenticado, no hacemos nada y actualizamos el estado.
    if (_currentUser != null) {
      setState(() {
        _currentAuthStatus = AuthStatus.signedIn;
      });
      return;
    }
    try {
      // Intenta iniciar sesión anónimamente con Firebase.
      final credential = await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _currentUser = credential.user; // Almacena el usuario autenticado
        _currentAuthStatus = AuthStatus.signedIn; // Actualiza el estado a "logeado"
        _apiResponseMessage = '¡Autenticación anónima exitosa!'; // Mensaje de éxito
      });
    } catch (e) {
      // Captura cualquier error durante la autenticación.
      setState(() {
        _currentAuthStatus = AuthStatus.error; // Actualiza el estado a "error"
        _apiResponseMessage = 'Error al iniciar sesión: $e'; // Muestra el error
      });
    }
  }

  // Maneja el cierre de sesión del usuario.
  Future<void> _handleUserSignOut() async {
    try {
      // Cierra la sesión de Firebase.
      await FirebaseAuth.instance.signOut();
      setState(() {
        _currentUser = null; // Limpia el usuario actual
        _currentAuthStatus = AuthStatus.notSignedIn; // Actualiza el estado a "no logeado"
        _apiResponseMessage = 'Sesión cerrada correctamente.'; // Mensaje de éxito
        _currentApiStatus = ApiRequestStatus.idle; // Reinicia el estado de la API
      });
    } catch (e) {
      // Captura cualquier error al cerrar sesión.
      setState(() {
        _apiResponseMessage = 'Error al cerrar sesión: $e'; // Muestra el error
      });
    }
  }

  // --- Método de Interacción con la API ---

  // Obtiene un saludo de tu servidor API.
  Future<void> _fetchApiGreeting() async {
    // Si el usuario no está autenticado, muestra un mensaje y no procede.
    if (_currentUser == null) {
      setState(() {
        _currentApiStatus = ApiRequestStatus.requiresAuth; // Estado de "requiere autenticación"
        _apiResponseMessage = 'Por favor, inicia sesión para obtener el saludo.'; // Mensaje al usuario
      });
      return;
    }

    setState(() {
      _currentApiStatus = ApiRequestStatus.loading; // Estado de "cargando"
      _apiResponseMessage = 'Conectando al servidor...'; // Mensaje de carga
    });

    try {
      // Realiza una solicitud GET a tu API y establece un tiempo de espera.
      final response = await http
          .get(Uri.parse('http://192.168.214.1:3000/saludo'))
          .timeout(const Duration(seconds: 7)); // Tiempo de espera de 7 segundos

      // Si la respuesta es exitosa (código 200 OK).
      if (response.statusCode == 200) {
        // Decodifica la respuesta JSON.
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _currentApiStatus = ApiRequestStatus.success; // Estado de "éxito"
          // Muestra el mensaje de la API o un mensaje por defecto.
          _apiResponseMessage = data['mensaje'] ?? 'Saludo recibido (sin mensaje específico).';
        });
      } else {
        // Si el código de estado no es 200.
        setState(() {
          _currentApiStatus = ApiRequestStatus.failure; // Estado de "fallo"
          _apiResponseMessage = 'Error en el servidor: Código ${response.statusCode}'; // Muestra el error
        });
      }
    } on TimeoutException {
      // Maneja el caso en que la solicitud excede el tiempo de espera.
      setState(() {
        _currentApiStatus = ApiRequestStatus.failure; // Estado de "fallo"
        _apiResponseMessage = 'Tiempo de espera agotado. Servidor no responde.'; // Mensaje de timeout
      });
    } on Exception catch (e) {
      // Captura cualquier otra excepción durante la conexión.
      setState(() {
        _currentApiStatus = ApiRequestStatus.failure; // Estado de "fallo"
        _apiResponseMessage = 'Error de conexión: $e'; // Muestra el error general
      });
    }
  }

  // --- Método Auxiliar para el Texto del Estado de Autenticación ---
  // Devuelve un texto legible para el usuario basado en el estado de autenticación.
  String _getAuthStatusText() {
    switch (_currentAuthStatus) {
      case AuthStatus.initial:
        return 'Verificando estado...';
      case AuthStatus.signedIn:
        return 'Sesión activa';
      case AuthStatus.notSignedIn:
        return 'Sin sesión iniciada';
      case AuthStatus.error:
        return 'Error de autenticación';
    }
  }

  // --- Método Build para la UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autenticación y API'), // Título de la barra de aplicación
        centerTitle: true, // Centra el título
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0), // Relleno general para el contenido
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centra los elementos verticalmente
          crossAxisAlignment: CrossAxisAlignment.stretch, // Estira los elementos horizontalmente
          children: [
            // Muestra el estado actual de la autenticación.
            Text(
              _getAuthStatusText(),
              style: Theme.of(context).textTheme.headlineSmall, // Estilo de texto
              textAlign: TextAlign.center, // Alineación del texto
            ),
            const SizedBox(height: 20), // Espacio vertical

            // Muestra el UID del usuario si está autenticado.
            if (_currentUser != null) ...[
              Text(
                'UID: ${_currentUser!.uid}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30), // Espacio después del UID
            ] else ...[
              const SizedBox(height: 10), // Espacio ajustado si no hay UID
            ],

            // Botones de acción
            FilledButton.icon(
              onPressed: _handleAnonymousSignIn, // Llama al método de inicio de sesión
              icon: const Icon(Icons.person_outline), // Icono del botón
              label: const Text('Iniciar Sesión (Anónimo)'), // Texto del botón
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12), // Relleno vertical
              ),
            ),
            const SizedBox(height: 16), // Espacio entre botones

            OutlinedButton.icon(
              onPressed: _fetchApiGreeting, // Llama al método para obtener saludo de API
              icon: _currentApiStatus == ApiRequestStatus.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2), // Muestra un spinner si está cargando
                    )
                  : const Icon(Icons.cloud_download), // Icono si no está cargando
              label: const Text('Obtener Mensaje de Servidor'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Botón de cerrar sesión (solo visible si el usuario está logeado)
            if (_currentUser != null)
              TextButton.icon(
                onPressed: _handleUserSignOut, // Llama al método de cerrar sesión
                icon: const Icon(Icons.logout), // Icono de cerrar sesión
                label: const Text('Cerrar Sesión'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error, // Color de texto de error
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

            const SizedBox(height: 40), // Espacio antes del mensaje de la API

            // Contenedor para mostrar el mensaje de la API
            Container(
              padding: const EdgeInsets.all(16), // Relleno interno del contenedor
              decoration: BoxDecoration(
                color: _getApiMessageBackgroundColor(), // Color de fondo dinámico
                borderRadius: BorderRadius.circular(10), // Bordes redondeados
                border: Border.all(
                  color: _getApiMessageBorderColor(), // Color del borde dinámico
                  width: 1,
                ),
              ),
              child: Text(
                // Muestra un mensaje por defecto o el mensaje de la API.
                _apiResponseMessage.isEmpty ? 'Aquí aparecerán los mensajes.' : _apiResponseMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: _getApiMessageTextColor(), // Color del texto dinámico
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Métodos Auxiliares para el Estilo del Mensaje de la API ---
  // Determina el color de fondo del mensaje de la API según su estado.
  Color _getApiMessageBackgroundColor() {
    switch (_currentApiStatus) {
      case ApiRequestStatus.success:
        return Colors.green.shade50;
      case ApiRequestStatus.failure:
      case ApiRequestStatus.requiresAuth:
        return Colors.red.shade50;
      case ApiRequestStatus.loading:
        return Colors.blue.shade50;
      case ApiRequestStatus.idle:
      default:
        return Theme.of(context).cardColor; // Color por defecto del tema
    }
  }

  // Determina el color del texto del mensaje de la API según su estado.
  Color _getApiMessageTextColor() {
    switch (_currentApiStatus) {
      case ApiRequestStatus.success:
        return Colors.green.shade800;
      case ApiRequestStatus.failure:
      case ApiRequestStatus.requiresAuth:
        return Colors.red.shade800;
      case ApiRequestStatus.loading:
        return Colors.blue.shade800;
      case ApiRequestStatus.idle:
      default:
        return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87; // Color por defecto del texto
    }
  }

  // Determina el color del borde del mensaje de la API según su estado.
  Color _getApiMessageBorderColor() {
    switch (_currentApiStatus) {
      case ApiRequestStatus.success:
        return Colors.green.shade200;
      case ApiRequestStatus.failure:
      case ApiRequestStatus.requiresAuth:
        return Colors.red.shade200;
      case ApiRequestStatus.loading:
        return Colors.blue.shade200;
      case ApiRequestStatus.idle:
      default:
        return Colors.grey.shade300; // Color por defecto del borde
    }
  }
}