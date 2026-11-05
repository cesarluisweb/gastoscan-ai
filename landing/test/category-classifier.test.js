import test from 'node:test';
import assert from 'node:assert/strict';
import {
    normalizar,
    clasificarCategoria,
    isTaxDescription,
    sincronizarCategoriaImpuestos,
} from '../src/lib/category-classifier.js';

test('Normalización de diacríticos y caracteres especiales', () => {
    assert.equal(normalizar('¡¡Jamón, Queso y Pan!!'), 'jamon queso y pan');
    assert.equal(normalizar('Piña & Café'), 'pina cafe');
    assert.equal(normalizar('Pantalón (Azul)'), 'pantalon azul');
    assert.equal(normalizar('Año Nuevo'), 'ano nuevo');
});

test('Cobertura de categorías oficiales canónicas', () => {
    // Alimentación
    assert.equal(clasificarCategoria('Harina PAN'), 'Alimentación');
    assert.equal(clasificarCategoria('Queso blanco llanero'), 'Alimentación');
    assert.equal(clasificarCategoria('Medio kilo de jamón'), 'Alimentación');
    assert.equal(clasificarCategoria('Pollo entero'), 'Alimentación');
    assert.equal(clasificarCategoria('Café molido'), 'Alimentación');

    // Salud
    assert.equal(clasificarCategoria('Acetaminofén 500mg'), 'Salud');
    assert.equal(clasificarCategoria('Ibuprofeno tabletas'), 'Salud');
    assert.equal(clasificarCategoria('Medicina para la gripe'), 'Salud');
    assert.equal(clasificarCategoria('Consulta odontólogo'), 'Salud');

    // Higiene
    assert.equal(clasificarCategoria('Champú anticaspa'), 'Higiene');
    assert.equal(clasificarCategoria('Jabón de baño dove'), 'Higiene');
    assert.equal(clasificarCategoria('Desodorante en barra'), 'Higiene');
    assert.equal(clasificarCategoria('Corte de cabello'), 'Higiene');

    // Transporte
    assert.equal(clasificarCategoria('Carrera de taxi'), 'Transporte');
    assert.equal(clasificarCategoria('Viaje en ridery'), 'Transporte');
    assert.equal(clasificarCategoria('Gasolina para el carro'), 'Transporte');

    // Servicios
    assert.equal(clasificarCategoria('Recarga digitel'), 'Servicios');
    assert.equal(clasificarCategoria('Pago de cantv'), 'Servicios');
    assert.equal(clasificarCategoria('Bombona de gas doméstico'), 'Servicios');

    // Hogar
    assert.equal(clasificarCategoria('Bombillo led 12w'), 'Hogar');
    assert.equal(clasificarCategoria('Detergente en polvo'), 'Hogar');
    assert.equal(clasificarCategoria('Cloro para desinfectar'), 'Hogar');

    // Educación
    assert.equal(clasificarCategoria('Cuaderno de una línea'), 'Educación');
    assert.equal(clasificarCategoria('Útiles escolares'), 'Educación');

    // Ropa
    assert.equal(clasificarCategoria('Pantalón jean'), 'Ropa');
    assert.equal(clasificarCategoria('Camisa blanca'), 'Ropa');

    // Entretenimiento
    assert.equal(clasificarCategoria('Entradas para el cine'), 'Entretenimiento');
    assert.equal(clasificarCategoria('Suscripción de netflix'), 'Entretenimiento');
});

test('Frases compuestas y desambiguación', () => {
    assert.equal(clasificarCategoria('Viaje en ridery'), 'Transporte');
    assert.equal(clasificarCategoria('Viaje en taxi'), 'Transporte');
    assert.equal(clasificarCategoria('Viaje a la playa'), 'Entretenimiento');

    assert.equal(clasificarCategoria('Almuerzo en restaurante'), 'Entretenimiento');
    assert.equal(clasificarCategoria('Cena en restaurante'), 'Entretenimiento');
    assert.equal(clasificarCategoria('Almuerzo ejecutivo'), 'Alimentación');

    assert.equal(clasificarCategoria('Aceite de motor'), 'Transporte');
    assert.equal(clasificarCategoria('Aceite de oliva'), 'Alimentación');

    assert.equal(clasificarCategoria('Pasta dental'), 'Higiene');
    assert.equal(clasificarCategoria('Pasta de tomate'), 'Alimentación');
});

test('Términos ambiguos aislados no fuerzan categoría errónea', () => {
    assert.equal(clasificarCategoria('Aceite'), null);
    assert.equal(clasificarCategoria('Gas'), null);
    assert.equal(clasificarCategoria('Batería'), null);
    assert.equal(clasificarCategoria('Agua'), null);
});

test('Detección y sincronización de Impuesto IVA con categoría dominante', () => {
    assert.equal(isTaxDescription('Impuesto IVA'), true);
    assert.equal(isTaxDescription('IVA 16%'), true);
    assert.equal(isTaxDescription('Harina'), false);

    const items = [
        { descripcion: 'Harina PAN', categoria: 'Alimentación', total: 100 },
        { descripcion: 'Carne molida', categoria: 'Alimentación', total: 200 },
        { descripcion: 'Impuesto IVA', categoria: 'Otros', total: 48, origenCategoria: 'auto' },
    ];

    const synced = sincronizarCategoriaImpuestos(items);
    assert.equal(synced[2].categoria, 'Alimentación');
});
