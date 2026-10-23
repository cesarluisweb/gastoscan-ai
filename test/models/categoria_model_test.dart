import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/models/categoria_model.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';

void main() {
  group('CategoriaModel Tests', () {
    test('instantiates with required nombre and default presupuestoMensual 0.0', () {
      final model = CategoriaModel(nombre: 'Alimentación');

      expect(model.id, isNull);
      expect(model.nombre, 'Alimentación');
      expect(model.name, 'Alimentación');
      expect(model.presupuestoMensual, 0.0);
      expect(model.presupuesto, 0.0);
      expect(model.budget, 0.0);
    });

    test('instantiates with custom id and presupuestoMensual', () {
      final model = CategoriaModel(
        id: 1,
        nombre: 'Comida',
        presupuestoMensual: 50.0,
      );

      expect(model.id, 1);
      expect(model.nombre, 'Comida');
      expect(model.presupuestoMensual, 50.0);
      expect(model.budget, 50.0);
    });

    test('toMap produces correct key-value map with id', () {
      final model = CategoriaModel(
        id: 10,
        nombre: 'Salud',
        presupuestoMensual: 120.5,
      );

      final map = model.toMap();

      expect(map['id'], 10);
      expect(map['nombre'], 'Salud');
      expect(map['presupuesto_mensual'], 120.5);
    });

    test('toMap omits id when null', () {
      final model = CategoriaModel(
        nombre: 'Transporte',
        presupuestoMensual: 45.0,
      );

      final map = model.toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['nombre'], 'Transporte');
      expect(map['presupuesto_mensual'], 45.0);
    });

    test('fromMap parses standard map correctly', () {
      final map = {
        'id': 5,
        'nombre': 'Educación',
        'presupuesto_mensual': 200.0,
      };

      final model = CategoriaModel.fromMap(map);

      expect(model.id, 5);
      expect(model.nombre, 'Educación');
      expect(model.presupuestoMensual, 200.0);
    });

    test('fromMap parses integer budget as double', () {
      final map = {
        'id': 2,
        'nombre': 'Comida',
        'presupuesto_mensual': 50, // int instead of double
      };

      final model = CategoriaModel.fromMap(map);

      expect(model.presupuestoMensual, 50.0);
    });

    test('fromMap supports fallback aliases: name, budget, presupuesto, categoria', () {
      final map1 = {
        'name': 'Hogar',
        'budget': 80.0,
      };
      final model1 = CategoriaModel.fromMap(map1);
      expect(model1.nombre, 'Hogar');
      expect(model1.presupuestoMensual, 80.0);

      final map2 = {
        'categoria': 'Servicios',
        'presupuesto': 35.5,
      };
      final model2 = CategoriaModel.fromMap(map2);
      expect(model2.nombre, 'Servicios');
      expect(model2.presupuestoMensual, 35.5);
    });

    test('copyWith updates specified fields correctly', () {
      final original = CategoriaModel(
        id: 1,
        nombre: 'Comida',
        presupuestoMensual: 50.0,
      );

      final updated = original.copyWith(
        presupuestoMensual: 75.0,
      );

      expect(updated.id, 1);
      expect(updated.nombre, 'Comida');
      expect(updated.presupuestoMensual, 75.0);

      final renamed = original.copyWith(nombre: 'Alimentos');
      expect(renamed.nombre, 'Alimentos');
      expect(renamed.presupuestoMensual, 50.0);
    });

    test('equality and hashCode work as expected', () {
      final a = CategoriaModel(id: 1, nombre: 'Comida', presupuestoMensual: 50.0);
      final b = CategoriaModel(id: 1, nombre: 'Comida', presupuestoMensual: 50.0);
      final c = CategoriaModel(id: 2, nombre: 'Comida', presupuestoMensual: 50.0);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('CategoryModel typedef works interchangeably', () {
      final CategoryModel model = CategoryModel(
        nombre: 'Comida',
        presupuestoMensual: 50.0,
      );

      expect(model, isA<CategoriaModel>());
      expect(model.presupuestoMensual, 50.0);
    });

    test('AppConstants.normalizarCategoria maps synonyms to official catalog', () {
      expect(AppConstants.normalizarCategoria('Alimentos'), 'Alimentación');
      expect(AppConstants.normalizarCategoria('alimentacion'), 'Alimentación');
      expect(AppConstants.normalizarCategoria('comida'), 'Alimentación');
      expect(AppConstants.normalizarCategoria('farmacia'), 'Salud');
      expect(AppConstants.normalizarCategoria('aseo'), 'Higiene');
      expect(AppConstants.normalizarCategoria('pasaje'), 'Transporte');
      expect(AppConstants.normalizarCategoria('gasolina'), 'Transporte');
      expect(AppConstants.normalizarCategoria('casa'), 'Hogar');
      expect(AppConstants.normalizarCategoria('servicio'), 'Servicios');
      expect(AppConstants.normalizarCategoria('estudios'), 'Educación');
      expect(AppConstants.normalizarCategoria('Ropa'), 'Ropa');
      expect(AppConstants.normalizarCategoria('calzado'), 'Ropa');
      expect(AppConstants.normalizarCategoria('Entretenimiento'), 'Entretenimiento');
      expect(AppConstants.normalizarCategoria('cine'), 'Entretenimiento');
      expect(AppConstants.normalizarCategoria('Categoría Inexistente'), 'Otros');
      expect(AppConstants.normalizarCategoria(null), 'Otros');
      expect(AppConstants.categorias.length, 10);
    });

    test('GastoModel and ItemGastoModel normalize category fromMap', () {
      final gasto = GastoModel.fromMap({
        'categoria': 'Alimentos',
        'comercio': 'Automercado',
        'total_usd': 1500,
      });
      expect(gasto.categoria, 'Alimentación');

      final item = ItemGastoModel.fromMap({
        'categoria': 'alimentos',
        'descripcion': 'Arroz',
        'total': 150,
      });
      expect(item.categoria, 'Alimentación');
    });

    test('AppConstants.normalizarMoneda maps currency symbols and synonyms to standard currencies', () {
      expect(AppConstants.normalizarMoneda('VES'), 'VES');
      expect(AppConstants.normalizarMoneda('bs'), 'VES');
      expect(AppConstants.normalizarMoneda('Bs.'), 'VES');
      expect(AppConstants.normalizarMoneda('bolívares'), 'VES');
      expect(AppConstants.normalizarMoneda('bolivares'), 'VES');
      expect(AppConstants.normalizarMoneda('dolares'), 'USD');
      expect(AppConstants.normalizarMoneda('dólares'), 'USD');
      expect(AppConstants.normalizarMoneda('\$'), 'USD');
      expect(AppConstants.normalizarMoneda('euros'), 'EUR');
      expect(AppConstants.normalizarMoneda('€'), 'EUR');
      expect(AppConstants.normalizarMoneda('usdt'), 'USDT');
      expect(AppConstants.normalizarMoneda(null), 'USD');
      expect(AppConstants.normalizarMoneda('xyz', fallback: 'VES'), 'VES');
    });

    test('AppConstants.detectarMonedaDeTexto extracts currency from voice speech', () {
      expect(AppConstants.detectarMonedaDeTexto('compré pan en 1500 bolívares'), 'VES');
      expect(AppConstants.detectarMonedaDeTexto('pagué 200 bs de pasaje'), 'VES');
      expect(AppConstants.detectarMonedaDeTexto('gasté 10 dolares en el almuerzo'), 'USD');
      expect(AppConstants.detectarMonedaDeTexto('compré café por 5\$'), 'USD');
      expect(AppConstants.detectarMonedaDeTexto('pagué 15 euros'), 'EUR');
      expect(AppConstants.detectarMonedaDeTexto('transferí 20 usdt'), 'USDT');
      expect(AppConstants.detectarMonedaDeTexto('compré 3 manzanas por 50'), 'USD');
    });
  });
}
