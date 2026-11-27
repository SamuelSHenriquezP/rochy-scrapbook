Pruebas locales de permisos (Java 21 y Node 22 o posterior):

npm install --prefix security_tests
npm --prefix security_tests test

El comando utiliza exclusivamente el proyecto demo de los emuladores. No inicia
sesion ni modifica Firebase real. Comprueba ambos perfiles, datos y archivos
privados, compartidos, solo vista, recuperacion y cambio de codigos.
