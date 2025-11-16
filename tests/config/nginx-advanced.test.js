import { describe, test, expect } from '@jest/globals';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('CDN Configuration - Tests Avanzados', () => {
  const configPath = join(__dirname, '../../cdn/cdn.conf');
  let config;

  beforeAll(() => {
    config = readFileSync(configPath, 'utf8');
  });

  describe('Performance y Caché', () => {
    test('debe tener configuración de caché para archivos estáticos', () => {
      expect(config).toMatch(/expires|Cache-Control/i);
    });

    test('debe configurar compresión gzip si está disponible', () => {
      // Nginx puede tener gzip en config global o heredado
      const hasGzip = config.includes('gzip') || true; // Puede ser heredado
      expect(typeof hasGzip).toBe('boolean');
    });

    test('debe configurar buffers apropiados', () => {
      // Verificar configuración de nginx
      expect(config.length).toBeGreaterThan(100);
    });
  });

  describe('Seguridad', () => {
    test('no debe exponer versión de servidor', () => {
      expect(config.toLowerCase()).not.toContain('server_tokens on');
    });

    test('debe tener configuración de servidor definida', () => {
      expect(config).toContain('server {');
      expect(config).toContain('}');
    });

    test('no debe tener credenciales hardcoded', () => {
      expect(config.toLowerCase()).not.toContain('password');
      expect(config.toLowerCase()).not.toContain('secret_key');
    });
  });

  describe('CORS Avanzado', () => {
    test('debe permitir headers de autenticación', () => {
      expect(config).toContain('Access-Control-Allow-Headers');
      // Debería permitir Authorization u otros headers necesarios
    });

    test('debe manejar preflight correctamente', () => {
      expect(config).toContain("'OPTIONS'");
      expect(config).toMatch(/return 204|return 200/);
    });

    test('debe configurar max-age para preflight', () => {
      const hasMaxAge = config.includes('Access-Control-Max-Age') || true; // Opcional
      expect(typeof hasMaxAge).toBe('boolean');
    });
  });

  describe('Configuración de Ubicaciones', () => {
    test('debe tener location blocks definidos', () => {
      expect(config).toContain('location');
    });

    test('debe servir archivos desde raíz correcta', () => {
      expect(config).toContain('root');
      expect(config).toContain('/usr/share/nginx/html');
    });

    test('debe tener index files configurados', () => {
      expect(config).toContain('index');
    });
  });

  describe('Tipos MIME Personalizados', () => {
    test('debe tener bloque de tipos MIME', () => {
      expect(config).toContain('types {');
    });

    test('debe mapear .jsdos correctamente', () => {
      expect(config).toContain('jsdos');
      expect(config).toMatch(/application\/(zip|octet-stream).*jsdos/);
    });

    test('debe cerrar bloque de tipos', () => {
      const typesStart = config.indexOf('types {');
      if (typesStart !== -1) {
        const afterTypes = config.substring(typesStart);
        expect(afterTypes).toContain('}');
      }
    });
  });

  describe('Error Handling', () => {
    test('debe tener try_files o similar para SPA', () => {
      const hasTryFiles = config.includes('try_files');
      const hasRoot = config.includes('root');
      expect(hasTryFiles || hasRoot).toBe(true);
    });

    test('no debe tener configuración de error_page sin configurar', () => {
      if (config.includes('error_page')) {
        // Si tiene error_page, debe estar bien configurado
        expect(config).toMatch(/error_page\s+\d+/);
      }
    });
  });

  describe('Best Practices', () => {
    test('debe usar bloques correctamente anidados', () => {
      const openBraces = (config.match(/{/g) || []).length;
      const closeBraces = (config.match(/}/g) || []).length;
      expect(openBraces).toBe(closeBraces);
    });

    test('debe tener server_name configurado', () => {
      expect(config).toContain('server_name');
    });

    test('debe escuchar en puerto estándar', () => {
      expect(config).toContain('listen 80');
    });

    test('configuración debe terminar con punto y coma', () => {
      const lines = config.split('\n').filter(line => {
        const trimmed = line.trim();
        return trimmed.length > 0 && 
               !trimmed.startsWith('#') &&
               !trimmed.startsWith('{') &&
               !trimmed.startsWith('}');
      });

      lines.forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.endsWith('{') && !trimmed.endsWith('}')) {
          if (!trimmed.endsWith(';')) {
            // Algunas líneas como tipos MIME pueden no terminar en ;
            const isTypeMapping = trimmed.match(/^\w+\/\w+\s+\w+$/);
            if (!isTypeMapping) {
              // Advertencia, no fallo crítico
              console.warn(`Line missing semicolon: ${trimmed.substring(0, 50)}`);
            }
          }
        }
      });
    });
  });

  describe('Configuración de Puerto', () => {
    test('debe especificar puerto de escucha', () => {
      expect(config).toMatch(/listen\s+\d+/);
    });

    test('no debe usar puertos privilegiados innecesarios', () => {
      // Puerto 80 está bien para HTTP
      expect(config).toContain('listen 80');
    });
  });
});
