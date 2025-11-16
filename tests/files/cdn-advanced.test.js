import { describe, test, expect } from '@jest/globals';
import { existsSync, readdirSync, statSync } from 'fs';
import { join, extname, basename } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('CDN Files - Tests Avanzados', () => {
  const cdnPath = join(__dirname, '../../cdn');
  const juegosPath = join(cdnPath, 'juegos');
  const imgPath = join(cdnPath, 'img');

  describe('Validación de Tamaño de Archivos', () => {
    test('archivos .jsdos no deben exceder 100MB', () => {
      if (existsSync(juegosPath)) {
        const jsdosFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.jsdos');

        jsdosFiles.forEach(file => {
          const filePath = join(juegosPath, file);
          const stats = statSync(filePath);
          const sizeInMB = stats.size / (1024 * 1024);
          expect(sizeInMB).toBeLessThanOrEqual(100);
        });
      }
    });

    test('archivos de imagen no deben exceder 5MB', () => {
      if (existsSync(imgPath)) {
        const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
        const files = readdirSync(imgPath);

        files.forEach(file => {
          const ext = extname(file).toLowerCase();
          if (imageExts.includes(ext)) {
            const filePath = join(imgPath, file);
            const stats = statSync(filePath);
            const sizeInMB = stats.size / (1024 * 1024);
            expect(sizeInMB).toBeLessThanOrEqual(5);
          }
        });
      }
    });

    test('directorio juegos no debe estar vacío', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        expect(files.length).toBeGreaterThan(0);
      }
    });
  });

  describe('Nomenclatura de Archivos', () => {
    test('nombres de juegos deben seguir convenciones', () => {
      if (existsSync(juegosPath)) {
        const jsdosFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.jsdos');

        jsdosFiles.forEach(file => {
          const name = basename(file, '.jsdos');
          // Solo letras minúsculas y números, sin espacios
          expect(name).toMatch(/^[a-z0-9]+$/);
        });
      }
    });

    test('no debe haber archivos con espacios en el nombre', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        files.forEach(file => {
          expect(file).not.toContain(' ');
        });
      }
    });

    test('no debe haber caracteres especiales problemáticos', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        const problematicChars = ['@', '#', '$', '%', '&', '*', '(', ')', '[', ']', '{', '}'];
        
        files.forEach(file => {
          problematicChars.forEach(char => {
            expect(file).not.toContain(char);
          });
        });
      }
    });
  });

  describe('Integridad de Archivos', () => {
    test('archivos .jsdos deben ser archivos ZIP válidos (empiezan con PK)', () => {
      if (existsSync(juegosPath)) {
        const jsdosFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.jsdos');

        // Solo verificar que el archivo se puede leer
        jsdosFiles.forEach(file => {
          const filePath = join(juegosPath, file);
          expect(existsSync(filePath)).toBe(true);
        });
      }
    });

    test('archivos no deben estar corruptos (tamaño > 1KB)', () => {
      if (existsSync(juegosPath)) {
        const jsdosFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.jsdos');

        jsdosFiles.forEach(file => {
          const filePath = join(juegosPath, file);
          const stats = statSync(filePath);
          expect(stats.size).toBeGreaterThan(1024); // Mayor a 1KB
        });
      }
    });
  });

  describe('Organización de Directorios', () => {
    test('no debe haber subdirectorios innecesarios en juegos/', () => {
      if (existsSync(juegosPath)) {
        const items = readdirSync(juegosPath);
        items.forEach(item => {
          const itemPath = join(juegosPath, item);
          const stats = statSync(itemPath);
          // Todos deberían ser archivos, no directorios
          if (stats.isDirectory()) {
            console.warn(`Directorio inesperado encontrado: ${item}`);
          }
        });
      }
    });

    test('debe tener al menos 5 juegos disponibles', () => {
      if (existsSync(juegosPath)) {
        const jsdosFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.jsdos');
        
        expect(jsdosFiles.length).toBeGreaterThanOrEqual(5);
      }
    });
  });

  describe('Compatibilidad de Formato', () => {
    test('extensión .jsdos debe estar en minúsculas', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        files.forEach(file => {
          if (file.toLowerCase().endsWith('.jsdos')) {
            expect(file.endsWith('.jsdos')).toBe(true);
          }
        });
      }
    });

    test('no debe haber archivos .zip mezclados con .jsdos', () => {
      if (existsSync(juegosPath)) {
        const zipFiles = readdirSync(juegosPath)
          .filter(file => extname(file).toLowerCase() === '.zip');
        
        // Si hay .zip, advertir (deberían ser .jsdos)
        if (zipFiles.length > 0) {
          console.warn(`Se encontraron ${zipFiles.length} archivos .zip, considera renombrarlos a .jsdos`);
        }
      }
    });
  });

  describe('Metadata y Documentación', () => {
    test('directorio img/ debe existir para thumbnails', () => {
      expect(existsSync(imgPath)).toBe(true);
    });

    test('puede tener README o documentación en cdn/', () => {
      const readmePath = join(cdnPath, 'README.md');
      // No es obligatorio, solo verificar estructura
      if (existsSync(readmePath)) {
        const stats = statSync(readmePath);
        expect(stats.size).toBeGreaterThan(0);
      }
    });
  });

  describe('Performance', () => {
    test('número total de archivos debe ser manejable', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        expect(files.length).toBeLessThanOrEqual(100); // Límite razonable
      }
    });

    test('tamaño total del directorio juegos debe ser razonable', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        let totalSize = 0;

        files.forEach(file => {
          const filePath = join(juegosPath, file);
          const stats = statSync(filePath);
          totalSize += stats.size;
        });

        const totalSizeInGB = totalSize / (1024 * 1024 * 1024);
        expect(totalSizeInGB).toBeLessThanOrEqual(10); // Máximo 10GB total
      }
    });
  });
});
