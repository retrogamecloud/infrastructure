import { describe, test, expect } from '@jest/globals';
import { readFileSync, existsSync, statSync, readdirSync } from 'fs';
import { join, extname } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('CDN Configuration - Tests de Validación', () => {
  const configPath = join(__dirname, '../../cdn/cdn.conf');
  let config;

  beforeAll(() => {
    config = readFileSync(configPath, 'utf8');
  });

  describe('Configuración Nginx básica', () => {
    test('debe existir archivo cdn.conf', () => {
      expect(existsSync(configPath)).toBe(true);
    });

    test('debe tener configuración de servidor', () => {
      expect(config).toContain('server {');
      expect(config).toContain('listen 80');
    });

    test('debe tener root y index configurados', () => {
      expect(config).toContain('root /usr/share/nginx/html');
      expect(config).toContain('index');
    });
  });

  describe('CORS Configuration', () => {
    test('debe tener headers CORS configurados', () => {
      expect(config).toContain('Access-Control-Allow-Origin');
      expect(config).toContain('Access-Control-Allow-Methods');
      expect(config).toContain('Access-Control-Allow-Headers');
    });

    test('debe permitir origen wildcard', () => {
      expect(config).toContain("'Access-Control-Allow-Origin' '*'");
    });

    test('debe manejar peticiones OPTIONS', () => {
      expect(config).toContain("$request_method = 'OPTIONS'");
      expect(config).toContain('return 204');
    });

    test('debe permitir métodos GET, HEAD, OPTIONS', () => {
      expect(config).toContain('GET, HEAD, OPTIONS');
    });
  });

  describe('MIME Types', () => {
    test('debe configurar tipo MIME para .jsdos', () => {
      expect(config).toContain('types {');
      expect(config).toContain('application/zip jsdos');
    });

    test('debe servir archivos .jsdos correctamente', () => {
      expect(config).toContain('location ~* \\.jsdos$');
    });
  });

  describe('Cache Configuration', () => {
    test('debe cachear recursos estáticos', () => {
      expect(config).toContain('location ~* \\.(jpg|jpeg|png|gif|ico|css|js)$');
      expect(config).toContain('expires');
    });

    test('debe tener Cache-Control para archivos .jsdos', () => {
      const jsdosLocation = config.match(/location ~\* \\\.jsdos\$[\s\S]*?\}/);
      expect(jsdosLocation).toBeTruthy();
      expect(jsdosLocation[0]).toContain('Cache-Control');
    });

    test('debe usar max-age apropiado', () => {
      expect(config).toContain('max-age=86400'); // 1 día
    });
  });

  describe('Health Check', () => {
    test('debe tener endpoint /health', () => {
      expect(config).toContain('location /health');
    });

    test('health check debe retornar 200', () => {
      const healthLocation = config.match(/location \/health[\s\S]*?\}/);
      expect(healthLocation).toBeTruthy();
      expect(healthLocation[0]).toContain('return 200');
    });

    test('health check debe desactivar access log', () => {
      const healthLocation = config.match(/location \/health[\s\S]*?\}/);
      expect(healthLocation[0]).toContain('access_log off');
    });
  });

  describe('Security', () => {
    test('no debe exponer información sensible', () => {
      expect(config.toLowerCase()).not.toContain('password');
      expect(config.toLowerCase()).not.toContain('secret');
      expect(config.toLowerCase()).not.toContain('apikey');
    });

    test('no debe tener directivas peligrosas', () => {
      expect(config).not.toContain('autoindex on');
      expect(config).not.toContain('allow all');
    });
  });

  describe('Best Practices', () => {
    test('debe usar comillas simples para headers', () => {
      const headerMatches = config.match(/add_header\s+'/g);
      expect(headerMatches).toBeTruthy();
      expect(headerMatches.length).toBeGreaterThan(0);
    });

    test('debe tener comentarios descriptivos', () => {
      const commentCount = (config.match(/#/g) || []).length;
      expect(commentCount).toBeGreaterThan(5);
    });

    test('configuración debe estar bien formateada', () => {
      const openBraces = (config.match(/{/g) || []).length;
      const closeBraces = (config.match(/}/g) || []).length;
      
      expect(openBraces).toBe(closeBraces);
    });
  });
});
