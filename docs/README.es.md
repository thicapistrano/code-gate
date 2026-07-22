# CODE-GATE - Analizador de Código Local con SonarQube

Ejecuta un análisis completo de SonarQube en cualquier proyecto local antes de abrir un PR — detecta vulnerabilidades, code smells, bugs y duplicaciones sin subir una sola línea de código.

> Traducciones: [English](../README.md) · [Português (BR)](README.pt-br.md)

---

## Cómo Funciona

```
Tu proyecto local
       │
       ▼
  analyze.sh          ← monta el directorio del proyecto en el contenedor sonar-scanner-cli
       │
       ▼
 SonarQube (Docker)   ← persiste los resultados en PostgreSQL
       │
       ▼
  Dashboard en el browser ← http://localhost:9020
```

1. **Docker Compose** levanta SonarQube Community + PostgreSQL localmente en el puerto `9020`.
2. **`analyze.sh`** inicia la imagen oficial `sonar-scanner-cli` de Docker, monta tu proyecto y envía los resultados a SonarQube.
3. Revisas los problemas encontrados en el dashboard antes de crear el PR.

---

## Requisitos Previos

| Herramienta    | Versión    | Nota                                                                           |
| -------------- | ---------- | ------------------------------------------------------------------------------ |
| Docker         | 20+        | [Instalar Docker](https://docs.docker.com/get-docker/)                         |
| Docker Compose | v2+        | Incluido en Docker Desktop; en Linux: `sudo apt install docker-compose-plugin` |
| `curl`         | cualquiera | Preinstalado en la mayoría de distros                                          |
| `make`         | cualquiera | `sudo apt install make`                                                        |

> **Requisito del kernel Linux** — SonarQube requiere `vm.max_map_count >= 524288`. Si el contenedor se detiene con un error de Elasticsearch, ejecuta:
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> # Para hacerlo permanente:
> echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
> ```

---

## Inicio Rápido

```bash
# 1. Navega hasta este proyecto
cd code-gate

# 2. Levanta SonarQube (la primera vez descarga ~600 MB de imágenes)
make start

# 3. Configuración inicial — cambia la contraseña por defecto y genera un token
#    Ejecutar una vez después de que SonarQube esté listo (≈ 60–90 segundos)
make setup

# 4. Analiza cualquier proyecto de tu máquina
make analyze DIR=/home/usuario/mi-proyecto

# 5. Abre el dashboard
make open
# o visita http://localhost:9020
```

---

## Uso Detallado

### Iniciar y Detener

```bash
make start      # inicia los contenedores en segundo plano
make stop       # detiene los contenedores (los datos se conservan)
make restart    # reinicia solo el contenedor de SonarQube
make status     # muestra el estado actual del sistema
make logs       # sigue los logs de SonarQube (Ctrl+C para salir)
```

### Ejecutar un Análisis

```bash
# Mínimo — la clave del proyecto se deriva del nombre del directorio
make analyze DIR=/ruta/al/proyecto

# Con clave y nombre personalizados
make analyze DIR=/ruta/al/proyecto KEY=mi-backend NAME="Mi Backend API"

# Usando el script directamente
./scripts/analyze.sh -p /ruta/al/proyecto -k mi-backend -n "Mi Backend API"
```

Al finalizar, el terminal muestra el enlace directo al dashboard del proyecto:

```
View results: http://localhost:9020/dashboard?id=mi-backend
```

### Configuración por Proyecto

Ejecuta `make init` para detectar automáticamente el lenguaje del proyecto y generar un `sonar-project.properties` listo para usar:

```bash
make init DIR=/ruta/al/proyecto
```

El script detecta el lenguaje por los archivos del proyecto (`pom.xml`, `go.mod`, `package.json`, etc.) y escribe las propiedades de cobertura correctas. Revisa el archivo generado, genera el informe de cobertura y ejecuta el análisis:

```bash
make analyze DIR=/ruta/al/proyecto
```

O copia y edita la plantilla completa manualmente:

```bash
cp config/sonar-project.properties.template /ruta/al/proyecto/sonar-project.properties
```

---

## Ignorar Archivos de Test

SonarQube trata los archivos de test de forma separada al código de producción. Puedes controlar este comportamiento en `sonar-project.properties`:

```properties
# Indica a SonarQube qué directorios contienen código de test
sonar.tests=src/test

# Excluye los tests de las métricas de calidad (code smells, duplicación, complejidad)
# pero mantiene el informe de cobertura
sonar.coverage.exclusions=**/test/**,**/__tests__/**,**/*Test.*,**/*.test.*,**/*.spec.*

# Excluye los archivos de test completamente de todo el análisis
# Usa esto si NO quieres ningún resultado relacionado con tests en el dashboard
sonar.exclusions=**/test/**,**/__tests__/**,**/*.test.*,**/*.spec.*
```

Usa `sonar.coverage.exclusions` para mantener el informe de cobertura pero ocultar los tests de las métricas de calidad. Usa `sonar.exclusions` para ignorarlos completamente.

---

## Cobertura de Código

SonarQube **no genera** cobertura por sí solo — lee un informe producido por tu herramienta de tests. El flujo es:

```
tu herramienta de test → genera informe → sonar-scanner lo lee → muestra en dashboard
```

### Paso 1 — Genera el informe de cobertura

**JavaScript / TypeScript (Jest)**
```bash
jest --coverage --coverageReporters=lcov
# salida: coverage/lcov.info
```

**Python (pytest-cov)**
```bash
pip install pytest-cov
pytest --cov=src --cov-report=xml
# salida: coverage.xml
```

**Java (Maven + JaCoCo)**

Agrega a `pom.xml`:
```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.11</version>
  <executions>
    <execution><goals><goal>prepare-agent</goal></goals></execution>
    <execution>
      <id>report</id><phase>test</phase>
      <goals><goal>report</goal></goals>
    </execution>
  </executions>
</plugin>
```
```bash
mvn test
# salida: target/site/jacoco/jacoco.xml
```

**Go**
```bash
go install github.com/jandelgado/gcov2lcov@latest
go test ./... -coverprofile=coverage.out
gcov2lcov -infile=coverage.out -outfile=coverage.lcov
# salida: coverage.out
```

**PHP (PHPUnit)**

Agrega a `phpunit.xml`:
```xml
<coverage>
  <report>
    <clover outputFile="coverage/clover.xml"/>
  </report>
</coverage>
```
```bash
./vendor/bin/phpunit --coverage-clover coverage/clover.xml
# salida: coverage/clover.xml
```

### Paso 2 — Apunta el informe en `sonar-project.properties`

```properties
# JavaScript / TypeScript
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.lcov.reportPaths=coverage/lcov.info

# Python
sonar.python.version=3
sonar.python.coverage.reportPaths=coverage.xml

# Java
sonar.java.binaries=target/classes
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml

# Go
sonar.go.coverage.reportPaths=coverage.out

# PHP
sonar.php.coverage.reportPaths=coverage/clover.xml
```

### Paso 3 — Ejecuta el análisis

```bash
make analyze DIR=/ruta/al/proyecto
```

> El panel de cobertura solo aparece después de que SonarQube recibe al menos un informe válido. Si el archivo de informe no existe en la ruta configurada, el scanner lo omite silenciosamente — confirma que el archivo fue generado antes de ejecutar `make analyze`.

---

## Estructura de Archivos

```
code-gate/
├── scripts/
│   ├── analyze.sh                          # Runner de análisis
│   ├── init-project.sh                     # Generador de configuración del proyecto
│   └── setup.sh                            # Helper de configuración inicial
├── config/
│   ├── docker-compose.yml                  # Servicios SonarQube + PostgreSQL
│   └── sonar-project.properties.template  # Plantilla de configuración del proyecto
├── docs/
│   ├── README.es.md                        # Este archivo (Español)
│   └── README.pt-br.md                     # Portugués (Brasil)
├── .env.example                            # Referencia de variables de entorno
├── .gitignore
├── Makefile                                # Comandos de conveniencia
└── README.md                               # Inglés
```

---

## Variables de Entorno

| Variable                   | Por defecto             | Descripción                                                             |
| -------------------------- | ----------------------- | ----------------------------------------------------------------------- |
| `SONARQUBE_URL`            | `http://localhost:9020` | URL base de SonarQube                                                   |
| `SONARQUBE_TOKEN`          | _(vacío)_               | Token de autenticación — generado por `make setup` y guardado en `.env` |
| `SONARQUBE_ADMIN_PASSWORD` | `Admin@12345678`        | Contraseña del admin definida durante `make setup`                      |

Las variables se leen automáticamente del archivo `.env` por `analyze.sh`. Copia `.env.example` a `.env` para personalizar.

---

## Referencia del Makefile

| Comando                   | Descripción                                            |
| ------------------------- | ------------------------------------------------------ |
| `make start`              | Inicia SonarQube y PostgreSQL                          |
| `make stop`               | Detiene todos los contenedores                         |
| `make restart`            | Reinicia el contenedor de SonarQube                    |
| `make setup`              | Configuración inicial (contraseña + token)             |
| `make init DIR=<ruta>`    | Genera el sonar-project.properties para un proyecto |
| `make analyze DIR=<ruta>` | Ejecuta el análisis en un proyecto                  |
| `make logs`               | Sigue los logs de SonarQube                            |
| `make status`             | Muestra el estado del sistema en JSON                  |
| `make open`               | Abre el dashboard en el navegador                      |
| `make clean`              | **Elimina todos los datos** (contenedores + volúmenes) |

---

## Solución de Problemas

### El contenedor de SonarQube se detiene de inmediato

Verifica la configuración del kernel:

```bash
make logs
# Si aparece "max virtual memory areas vm.max_map_count [...] is too low":
sudo sysctl -w vm.max_map_count=524288
```

### Nombre de contenedor ya en uso

Un contenedor anterior no fue eliminado correctamente. Ejecuta:

```bash
docker rm -f sonarqube sonarqube_db
make start
```

### "SonarQube is not running or not ready"

Espera a que el health check pase (~90 segundos en el primer inicio):

```bash
make status   # repite hasta ver "status":"UP"
```

### Errores de token o autenticación

Vuelve a ejecutar el setup para generar un nuevo token:

```bash
make setup
```

### Puerto 9020 ya en uso

Edita `config/docker-compose.yml` y cambia `"9020:9000"` a ej. `"9021:9000"`, luego actualiza `.env`:

```
SONARQUBE_URL=http://localhost:9021
```

### La cobertura no aparece en el dashboard

- Confirma que el archivo de informe fue generado antes de ejecutar `make analyze`
- Verifica que la ruta en `sonar-project.properties` coincide con el archivo generado
- Vuelve a ejecutar el análisis después de corregir la ruta

---

## Flujo Recomendado Pre-PR

1. Finaliza tu feature branch.
2. Genera el informe de cobertura con tu herramienta de tests.
3. Ejecuta `make analyze DIR=<tu-proyecto>`.
4. Corrige todos los problemas de tipo **Blocker** o **Critical** que aparecen en el dashboard.
5. Abre el PR solo después de que el Quality Gate pase (verde).

---

## Licencia

Este proyecto se distribuye bajo la [Licencia MIT](../LICENSE).  
SonarQube Community Edition está licenciado bajo la [GNU LGPL v3](https://www.gnu.org/licenses/lgpl-3.0.html).
