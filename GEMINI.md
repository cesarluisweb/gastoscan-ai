# Reglas Técnicas del Proyecto (Control de Gastos VE)

## 1. NPM y Google Drive
**IMPORTANTE:** Este proyecto se encuentra dentro de un directorio sincronizado por Google Drive.
NUNCA ejecutes comandos como 
pm install o 
pm run build directamente dentro de este directorio, ya que el cliente de Google Drive bloqueará los archivos (
ode_modules), provocando errores \EBUSY\, \EPERM\ o \EBADF\.
*Workaround:* Si necesitas compilar o instalar dependencias, copia la carpeta entera a una ubicación local temporal (ej. C:\Users\cesar\Desktop\landing_temp), ejecuta allí los comandos, y luego copia únicamente la salida (ej. dist/) de vuelta al proyecto.

## 2. Codificación en PowerShell
Cuando necesites crear o modificar archivos de texto o código utilizando el comando Set-Content en PowerShell, **SIEMPRE** debes usar el parámetro -Encoding UTF8.
Si omites este parámetro, Windows usará una codificación heredada y romperá todos los caracteres especiales (acentos, ñ, etc.) en español, lo que dañará el diseño y los textos en pantalla.
