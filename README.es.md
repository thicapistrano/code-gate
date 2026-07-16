# CODE-GATE - Analizador de Código Local con SonarQube

Ejecuta un análisis completo de SonarQube en cualquier proyecto local antes de abrir un PR — detecta vulnerabilidades, code smells, bugs y duplicaciones sin subir una sola línea de código.

> Traducciones: [English](README.md) · [Português (BR)](README.pt-br.md)

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
  Dashboard en el browser ← http://localhost:9000
```

1. **Docker Compose** levanta SonarQube Community + PostgreSQL localmente en el puerto `9000`.
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
# o visita http://localhost:9000
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
./analyze.sh -p /ruta/al/proyecto -k mi-backend -n "Mi Backend API"
```

Al finalizar, el terminal muestra el enlace directo al dashboard del proyecto:

```
View results: http://localhost:9000/dashboard?id=mi-backend
```

### Configuración por Proyecto

Para un control más fino (rutas de tests, informes de cobertura, configuraciones por lenguaje), copia la plantilla al proyecto objetivo:

```bash
cp sonar-project.properties.template /ruta/al/proyecto/sonar-project.properties
# Edítalo y vuelve a ejecutar el análisis
make analyze DIR=/ruta/al/proyecto
```

---

## Estructura de Archivos

```
code-gate/
├── docker-compose.yml                  # Servicios SonarQube + PostgreSQL
├── analyze.sh                          # Runner de análisis
├── setup.sh                            # Helper de configuración inicial
├── Makefile                            # Comandos de conveniencia
├── sonar-project.properties.template  # Plantilla de configuración del proyecto
├── .env.example                        # Referencia de variables de entorno
├── .gitignore
├── README.md                           # Inglés
├── README.es.md                        # Este archivo (Español)
└── README.pt-br.md                     # Portugués (Brasil)
```

---

## Variables de Entorno

| Variable                   | Por defecto             | Descripción                                                             |
| -------------------------- | ----------------------- | ----------------------------------------------------------------------- |
| `SONARQUBE_URL`            | `http://localhost:9000` | URL base de SonarQube                                                   |
| `SONARQUBE_TOKEN`          | _(vacío)_               | Token de autenticación — generado por `make setup` y guardado en `.env` |
| `SONARQUBE_ADMIN_PASSWORD` | `Admin@123`             | Contraseña del admin definida durante `make setup`                      |

Las variables se leen automáticamente del archivo `.env` por `analyze.sh`. Copia `.env.example` a `.env` para personalizar.

---

## Referencia del Makefile

| Comando                   | Descripción                                            |
| ------------------------- | ------------------------------------------------------ |
| `make start`              | Inicia SonarQube y PostgreSQL                          |
| `make stop`               | Detiene todos los contenedores                         |
| `make restart`            | Reinicia el contenedor de SonarQube                    |
| `make setup`              | Configuración inicial (contraseña + token)             |
| `make analyze DIR=<ruta>` | Ejecuta el análisis en un proyecto                     |
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

### Puerto 9000 ya en uso

Edita `docker-compose.yml` y cambia `"9000:9000"` a, por ejemplo, `"9001:9000"`, luego actualiza `.env`:

```
SONARQUBE_URL=http://localhost:9001
```

---

## Flujo Recomendado Pre-PR

1. Finaliza tu feature branch.
2. Ejecuta `make analyze DIR=<tu-proyecto>`.
3. Corrige todos los problemas de tipo **Blocker** o **Critical** que aparecen en el dashboard.
4. Abre el PR solo después de que el Quality Gate pase (verde).

---

## Licencia

Este proyecto se distribuye bajo la [Licencia MIT](LICENSE).  
SonarQube Community Edition está licenciado bajo la [GNU LGPL v3](https://www.gnu.org/licenses/lgpl-3.0.html).
