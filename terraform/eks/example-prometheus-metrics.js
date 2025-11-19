// ============================================================================
// Ejemplo: Instrumentación con Prometheus para Backend Node.js
// ============================================================================
//
// Este archivo muestra cómo añadir métricas de Prometheus a tu backend
// para que el ServiceMonitor pueda scrapearlas.
//
// INSTALACIÓN:
// npm install prom-client
//
// USO:
// 1. Copia este código a tu backend (ej: src/metrics/prometheus.js)
// 2. Importa setupPrometheus() en tu index.js
// 3. Llama setupPrometheus(app) después de crear el app de Express
// 4. Reinicia el backend
// 5. Prueba: curl http://backend:3000/metrics
//
// ============================================================================

const promClient = require('prom-client');

/**
 * Configura Prometheus metrics en una aplicación Express
 * @param {Express.Application} app - Aplicación Express
 */
function setupPrometheus(app) {
  
  // ============================================================================
  // 1. Habilitar métricas default de Node.js
  // ============================================================================
  // Métricas automáticas incluyen:
  // - process_cpu_user_seconds_total: CPU usado por el proceso
  // - process_resident_memory_bytes: Memoria RAM usada
  // - nodejs_eventloop_lag_seconds: Event loop lag (importante!)
  // - nodejs_heap_size_total_bytes: Heap total de Node.js
  // - nodejs_gc_duration_seconds: Garbage collection duration
  
  promClient.collectDefaultMetrics({
    timeout: 5000,  // Recolectar cada 5 segundos
    prefix: 'backend_',  // Prefijo para todas las métricas (ej: backend_process_cpu_user_seconds_total)
  });

  // ============================================================================
  // 2. Métricas HTTP personalizadas
  // ============================================================================
  
  // Contador de requests HTTP por método, ruta y status code
  const httpRequestCounter = new promClient.Counter({
    name: 'backend_http_requests_total',
    help: 'Total de requests HTTP recibidos',
    labelNames: ['method', 'route', 'status_code'],
  });

  // Histograma de duración de requests (para calcular latency promedio, p95, p99)
  const httpRequestDuration = new promClient.Histogram({
    name: 'backend_http_request_duration_seconds',
    help: 'Duración de requests HTTP en segundos',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10],  // Buckets en segundos
  });

  // Gauge para requests activos (cuántas requests están procesándose ahora)
  const httpRequestsInProgress = new promClient.Gauge({
    name: 'backend_http_requests_in_progress',
    help: 'Número de requests HTTP en proceso',
    labelNames: ['method'],
  });

  // ============================================================================
  // 3. Métricas de Base de Datos (opcional)
  // ============================================================================
  
  // Contador de queries a la DB
  const dbQueryCounter = new promClient.Counter({
    name: 'backend_db_queries_total',
    help: 'Total de queries ejecutadas en la base de datos',
    labelNames: ['operation', 'table'],
  });

  // Histograma de duración de queries
  const dbQueryDuration = new promClient.Histogram({
    name: 'backend_db_query_duration_seconds',
    help: 'Duración de queries de base de datos en segundos',
    labelNames: ['operation', 'table'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  });

  // ============================================================================
  // 4. Métricas de Negocio (ejemplo: juegos, usuarios)
  // ============================================================================
  
  // Contador de registros de usuarios
  const userRegistrations = new promClient.Counter({
    name: 'backend_user_registrations_total',
    help: 'Total de usuarios registrados',
  });

  // Gauge de usuarios activos (se puede actualizar periódicamente)
  const activeUsers = new promClient.Gauge({
    name: 'backend_active_users',
    help: 'Número de usuarios activos en los últimos 5 minutos',
  });

  // Contador de juegos cargados
  const gamesLoaded = new promClient.Counter({
    name: 'backend_games_loaded_total',
    help: 'Total de juegos cargados por los usuarios',
    labelNames: ['game_name'],
  });

  // ============================================================================
  // 5. Middleware para capturar métricas HTTP automáticamente
  // ============================================================================
  
  app.use((req, res, next) => {
    // Incrementar requests en progreso
    httpRequestsInProgress.inc({ method: req.method });
    
    // Iniciar timer para medir duración
    const startTime = Date.now();
    
    // Hook al finalizar response
    res.on('finish', () => {
      const duration = (Date.now() - startTime) / 1000;  // Convertir a segundos
      const route = req.route?.path || req.path || 'unknown';
      
      // Incrementar contador de requests
      httpRequestCounter.inc({
        method: req.method,
        route: route,
        status_code: res.statusCode,
      });
      
      // Registrar duración en histograma
      httpRequestDuration.observe(
        {
          method: req.method,
          route: route,
          status_code: res.statusCode,
        },
        duration
      );
      
      // Decrementar requests en progreso
      httpRequestsInProgress.dec({ method: req.method });
    });
    
    next();
  });

  // ============================================================================
  // 6. Endpoint /metrics para Prometheus
  // ============================================================================
  
  app.get('/metrics', async (req, res) => {
    try {
      res.set('Content-Type', promClient.register.contentType);
      const metrics = await promClient.register.metrics();
      res.end(metrics);
    } catch (error) {
      console.error('Error generando métricas:', error);
      res.status(500).end('Error generando métricas');
    }
  });

  // ============================================================================
  // 7. Exportar métricas para uso en controladores
  // ============================================================================
  // Puedes usar estas métricas manualmente en tus controladores:
  //
  // Ejemplo en authController.js:
  // const { userRegistrations } = require('./metrics/prometheus');
  // 
  // async function register(req, res) {
  //   // ... lógica de registro ...
  //   userRegistrations.inc();  // Incrementar contador
  //   res.json({ success: true });
  // }
  //
  // Ejemplo en gameController.js:
  // const { gamesLoaded } = require('./metrics/prometheus');
  // 
  // async function loadGame(req, res) {
  //   const { gameName } = req.params;
  //   // ... lógica de carga ...
  //   gamesLoaded.inc({ game_name: gameName });
  //   res.json({ game: gameData });
  // }
  
  return {
    httpRequestCounter,
    httpRequestDuration,
    httpRequestsInProgress,
    dbQueryCounter,
    dbQueryDuration,
    userRegistrations,
    activeUsers,
    gamesLoaded,
  };
}

// ============================================================================
// 8. Ejemplo de integración en index.js
// ============================================================================
//
// const express = require('express');
// const { setupPrometheus } = require('./metrics/prometheus');
//
// const app = express();
//
// // ... middlewares existentes (body-parser, cors, etc.) ...
//
// // Configurar Prometheus (debe ir ANTES de las rutas)
// const metrics = setupPrometheus(app);
//
// // ... tus rutas existentes ...
//
// app.listen(3000, () => {
//   console.log('Backend escuchando en puerto 3000');
//   console.log('Métricas disponibles en http://localhost:3000/metrics');
// });
//
// ============================================================================

module.exports = { setupPrometheus };
