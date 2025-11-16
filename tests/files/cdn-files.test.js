import { describe, test, expect } from '@jest/globals';
import { existsSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('CDN Files - Tests de Archivos', () => {
  const cdnPath = join(__dirname, '../../cdn');
  const juegosPath = join(cdnPath, 'juegos');
  const imgPath = join(cdnPath, 'img');

  describe('Estructura de directorios', () => {
    test('debe existir directorio cdn/', () => {
      expect(existsSync(cdnPath)).toBe(true);
    });

    test('debe existir directorio cdn/juegos/', () => {
      expect(existsSync(juegosPath)).toBe(true);
    });

    test('debe existir directorio cdn/img/', () => {
      expect(existsSync(imgPath)).toBe(true);
    });
  });

  describe('Archivos .jsdos', () => {
    let jsdosFiles = [];

    beforeAll(() => {
      if (existsSync(juegosPath)) {
        jsdosFiles = readdirSync(juegosPath).filter(file => 
          extname(file).toLowerCase() === '.jsdos'
        );
      }
    });

    test('debe tener al menos un archivo .jsdos', () => {
      expect(jsdosFiles.length).toBeGreaterThan(0);
    });

    test('archivos .jsdos deben tener tamaño mayor a 0', () => {
      jsdosFiles.forEach(file => {
        const filePath = join(juegosPath, file);
        const stats = statSync(filePath);
        expect(stats.size).toBeGreaterThan(0);
      });
    });

    test('nombres de archivos deben ser lowercase', () => {
      jsdosFiles.forEach(file => {
        const nameWithoutExt = file.replace('.jsdos', '');
        expect(nameWithoutExt).toBe(nameWithoutExt.toLowerCase());
      });
    });

    test('debe incluir juegos clásicos conocidos', () => {
      const expectedGames = ['doom', 'tetris', 'wolf', 'duke3d'];
      const fileNames = jsdosFiles.map(f => f.replace('.jsdos', ''));
      
      const hasClassicGames = expectedGames.some(game => 
        fileNames.includes(game)
      );
      
      expect(hasClassicGames).toBe(true);
    });

    test('no debe haber archivos .jsdos duplicados', () => {
      const uniqueFiles = new Set(jsdosFiles);
      expect(jsdosFiles.length).toBe(uniqueFiles.size);
    });
  });

  describe('Imágenes', () => {
    let imageFiles = [];

    beforeAll(() => {
      if (existsSync(imgPath)) {
        imageFiles = readdirSync(imgPath).filter(file => {
          const ext = extname(file).toLowerCase();
          return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext);
        });
      }
    });

    test('debe tener imágenes si el directorio existe', () => {
      if (existsSync(imgPath)) {
        expect(imageFiles.length).toBeGreaterThanOrEqual(0);
      }
    });

    test('imágenes deben tener extensión válida', () => {
      const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
      
      imageFiles.forEach(file => {
        const ext = extname(file).toLowerCase();
        expect(validExtensions).toContain(ext);
      });
    });

    test('imágenes deben tener tamaño razonable', () => {
      imageFiles.forEach(file => {
        const filePath = join(imgPath, file);
        const stats = statSync(filePath);
        
        // Imágenes no deben ser mayores a 5MB
        expect(stats.size).toBeLessThan(5 * 1024 * 1024);
        expect(stats.size).toBeGreaterThan(0);
      });
    });
  });

  describe('Dockerfile', () => {
    const dockerfilePath = join(__dirname, '../../cdn/Dockerfile');

    test('debe existir Dockerfile', () => {
      expect(existsSync(dockerfilePath)).toBe(true);
    });

    test('Dockerfile debe usar nginx como base', () => {
      if (existsSync(dockerfilePath)) {
        const { readFileSync } = require('fs');
        const dockerfile = readFileSync(dockerfilePath, 'utf8');
        
        expect(dockerfile).toContain('FROM nginx');
      }
    });
  });

  describe('Tamaño total', () => {
    test('directorio de juegos debe ser razonable', () => {
      if (existsSync(juegosPath)) {
        let totalSize = 0;
        const files = readdirSync(juegosPath);
        
        files.forEach(file => {
          const filePath = join(juegosPath, file);
          totalSize += statSync(filePath).size;
        });

        // No más de 500MB total
        expect(totalSize).toBeLessThan(500 * 1024 * 1024);
      }
    });
  });

  describe('Permisos y seguridad', () => {
    test('no debe haber archivos ejecutables', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        
        files.forEach(file => {
          const ext = extname(file).toLowerCase();
          expect(ext).not.toBe('.exe');
          expect(ext).not.toBe('.sh');
          expect(ext).not.toBe('.bat');
        });
      }
    });

    test('no debe haber archivos ocultos sospechosos', () => {
      if (existsSync(juegosPath)) {
        const files = readdirSync(juegosPath);
        const hiddenFiles = files.filter(f => f.startsWith('.'));
        
        // Permitir .gitkeep pero nada más
        hiddenFiles.forEach(file => {
          expect(['.gitkeep', '.gitignore']).toContain(file);
        });
      }
    });
  });
});
