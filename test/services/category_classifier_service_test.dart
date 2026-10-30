import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/services/category_classifier_service.dart';

void main() {
  group('CategoryClassifierService - Normalización y Diacríticos', () {
    test('normaliza mayúsculas, tildes, eñes y signos de puntuación', () {
      expect(CategoryClassifierService.normalizar('¡¡Jamón, Queso y Pan!!'), 'jamon queso y pan');
      expect(CategoryClassifierService.normalizar('Piña & Café'), 'pina cafe');
      expect(CategoryClassifierService.normalizar('Pantalón (Azul)'), 'pantalon azul');
      expect(CategoryClassifierService.normalizar('Año Nuevo'), 'ano nuevo');
    });
  });

  group('CategoryClassifierService - Cobertura de las 10 Categorías Canónicas', () {
    test('clasifica términos de Alimentación', () {
      expect(CategoryClassifierService.clasificar('Harina PAN'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Queso blanco llanero'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Medio kilo de jamón'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('1 kg de carne molida'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Pollo entero'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Café molido'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Arroz blanco'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Piña dulce'), 'Alimentación');
    });

    test('clasifica términos de Salud', () {
      expect(CategoryClassifierService.clasificar('Acetaminofén 500mg'), 'Salud');
      expect(CategoryClassifierService.clasificar('Ibuprofeno tabletas'), 'Salud');
      expect(CategoryClassifierService.clasificar('Medicina para la gripe'), 'Salud');
      expect(CategoryClassifierService.clasificar('Consulta odontólogo'), 'Salud');
      expect(CategoryClassifierService.clasificar('Jarabe para la tos'), 'Salud');
      expect(CategoryClassifierService.clasificar('Farmacia compra'), 'Salud');
    });

    test('clasifica términos de Higiene', () {
      expect(CategoryClassifierService.clasificar('Champú anticaspa'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Jabón de baño dove'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Desodorante en barra'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Afeitadora gillete'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Corte de cabello'), 'Higiene');
    });

    test('clasifica términos de Transporte', () {
      expect(CategoryClassifierService.clasificar('Carrera de taxi'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Viaje en ridery'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Gasolina para el carro'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Pasaje de camioneta'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Estacionamiento centro'), 'Transporte');
    });

    test('clasifica términos de Servicios', () {
      expect(CategoryClassifierService.clasificar('Recarga digitel'), 'Servicios');
      expect(CategoryClassifierService.clasificar('Pago de cantv'), 'Servicios');
      expect(CategoryClassifierService.clasificar('Factura de internet inter'), 'Servicios');
      expect(CategoryClassifierService.clasificar('Luz corpoelec'), 'Servicios');
      expect(CategoryClassifierService.clasificar('Bombona de gas doméstico'), 'Servicios');
    });

    test('clasifica términos de Hogar', () {
      expect(CategoryClassifierService.clasificar('Bombillo led 12w'), 'Hogar');
      expect(CategoryClassifierService.clasificar('Detergente en polvo'), 'Hogar');
      expect(CategoryClassifierService.clasificar('Cloro para desinfectar'), 'Hogar');
      expect(CategoryClassifierService.clasificar('Tornillos en ferretería'), 'Hogar');
      expect(CategoryClassifierService.clasificar('Sábanas para cama'), 'Hogar');
    });

    test('clasifica términos de Educación', () {
      expect(CategoryClassifierService.clasificar('Cuaderno de una línea'), 'Educación');
      expect(CategoryClassifierService.clasificar('Libro de matemáticas'), 'Educación');
      expect(CategoryClassifierService.clasificar('Matrícula del colegio'), 'Educación');
      expect(CategoryClassifierService.clasificar('Útiles escolares'), 'Educación');
    });

    test('clasifica términos de Ropa', () {
      expect(CategoryClassifierService.clasificar('Pantalón jean'), 'Ropa');
      expect(CategoryClassifierService.clasificar('Camisa blanca'), 'Ropa');
      expect(CategoryClassifierService.clasificar('Zapatos deportivos'), 'Ropa');
      expect(CategoryClassifierService.clasificar('Medias tobilleras'), 'Ropa');
      expect(CategoryClassifierService.clasificar('Franela deportiva'), 'Ropa');
    });

    test('clasifica términos de Entretenimiento', () {
      expect(CategoryClassifierService.clasificar('Entradas para el cine'), 'Entretenimiento');
      expect(CategoryClassifierService.clasificar('Suscripción de netflix'), 'Entretenimiento');
      expect(CategoryClassifierService.clasificar('Almuerzo en restaurante'), 'Entretenimiento');
      expect(CategoryClassifierService.clasificar('Chuchería variada'), 'Entretenimiento');
    });
  });

  group('CategoryClassifierService - Frases Compuestas y Desambiguación', () {
    test('desambigua viaje en ridery o taxi (Transporte) vs viaje vacacional (Entretenimiento)', () {
      expect(CategoryClassifierService.clasificar('Viaje en ridery'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Viaje en taxi'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Viaje a la playa'), 'Entretenimiento');
    });

    test('desambigua almuerzo o cena en restaurante (Entretenimiento) vs almuerzo normal (Alimentación)', () {
      expect(CategoryClassifierService.clasificar('Almuerzo en restaurante'), 'Entretenimiento');
      expect(CategoryClassifierService.clasificar('Cena en restaurante'), 'Entretenimiento');
      expect(CategoryClassifierService.clasificar('Almuerzo ejecutivo'), 'Alimentación');
    });

    test('desambigua aceite de motor (Transporte) vs aceite de maíz (Alimentación)', () {
      expect(CategoryClassifierService.clasificar('Aceite de motor 20w50'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Aceite motor sellado'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Aceite de maíz mazeite'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Aceite de oliva'), 'Alimentación');
      expect(CategoryClassifierService.clasificar('Aceite girasol'), 'Alimentación');
    });

    test('desambigua papel higiénico (Higiene) vs papel bond (Educación) vs papel toalla (Hogar)', () {
      expect(CategoryClassifierService.clasificar('Papel higiénico 4 rollos'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Papel sanitario suave'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Papel bond resma'), 'Educación');
      expect(CategoryClassifierService.clasificar('Papel toalla absorbente'), 'Hogar');
    });

    test('desambigua crema dental (Higiene) vs crema de leche (Alimentación)', () {
      expect(CategoryClassifierService.clasificar('Crema dental colgate'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Pasta dental oral b'), 'Higiene');
      expect(CategoryClassifierService.clasificar('Crema de leche la campiña'), 'Alimentación');
    });

    test('desambigua batería de carro (Transporte)', () {
      expect(CategoryClassifierService.clasificar('Batería de carro duncan'), 'Transporte');
      expect(CategoryClassifierService.clasificar('Batería carro nueva'), 'Transporte');
    });

    test('desambigua gas doméstico (Servicios) vs gas vehicular (Transporte)', () {
      expect(CategoryClassifierService.clasificar('Bombona de gas doméstico'), 'Servicios');
      expect(CategoryClassifierService.clasificar('Gas vehicular gnv'), 'Transporte');
    });

    test('términos ambiguos aislados retornan null para no forzar categoría errónea', () {
      expect(CategoryClassifierService.clasificar('aceite'), isNull);
      expect(CategoryClassifierService.clasificar('gas'), isNull);
      expect(CategoryClassifierService.clasificar('batería'), isNull);
      expect(CategoryClassifierService.clasificar('papel'), isNull);
      expect(CategoryClassifierService.clasificar('crema'), isNull);
      expect(CategoryClassifierService.clasificar('corte'), isNull);
      expect(CategoryClassifierService.clasificar('bar'), isNull);
      expect(CategoryClassifierService.clasificar('taller'), isNull);
      expect(CategoryClassifierService.clasificar('agua'), isNull);
    });
  });

  group('CategoryClassifierService - Límites de Palabra y Textos No Coincidentes', () {
    test('pantalón no activa pan como Alimentación', () {
      expect(CategoryClassifierService.clasificar('Pantalón de vestir'), 'Ropa');
    });

    test('gasolina no se anula por la palabra gas', () {
      expect(CategoryClassifierService.clasificar('Gasolina 95 octanos'), 'Transporte');
    });

    test('frases genéricas o desconocidas retornan null', () {
      expect(CategoryClassifierService.clasificar(''), isNull);
      expect(CategoryClassifierService.clasificar('ab'), isNull);
      expect(CategoryClassifierService.clasificar('cosa rara sin clasificar'), isNull);
      expect(CategoryClassifierService.clasificar('compré varias cosas en la panadería'), isNull);
    });

    test('todos los resultados son categorías oficiales de AppConstants.categorias', () {
      final testStrings = [
        'Harina', 'Pastilla', 'Jabón', 'Gasolina', 'Recarga', 'Bombillo',
        'Cuaderno', 'Camisa', 'Cine', 'Aceite de motor', 'Papel higiénico'
      ];
      for (final s in testStrings) {
        final cat = CategoryClassifierService.clasificar(s);
        expect(cat, isNotNull);
        expect(AppConstants.categorias.contains(cat), isTrue);
      }
    });
  });
}
