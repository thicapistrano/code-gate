# CODE-GATE - SonarQube Local Code Analyzer

Run a full SonarQube analysis against any local project before opening a PR — catch vulnerabilities, code smells, bugs, and duplications without pushing a single line.

> Translations: [Português (BR)](docs/README.pt-br.md) · [Español](docs/README.es.md)

---

## How It Works

```
Your local project
       │
       ▼
  analyze.sh          ← mounts project dir into sonar-scanner-cli container
       │
       ▼
 SonarQube (Docker)   ← persists results in PostgreSQL
       │
       ▼
  Browser dashboard   ← http://localhost:9020
```

1. **Docker Compose** runs SonarQube Community + PostgreSQL locally on port `9020`.
2. **`analyze.sh`** launches the official `sonar-scanner-cli` Docker image, mounts your project, and pushes results to SonarQube.
3. You review issues in the web dashboard before creating the PR.

---

## Prerequisites

| Tool           | Version | Notes                                                                           |
| -------------- | ------- | ------------------------------------------------------------------------------- |
| Docker         | 20+     | [Install Docker](https://docs.docker.com/get-docker/)                           |
| Docker Compose | v2+     | Bundled with Docker Desktop; on Linux: `sudo apt install docker-compose-plugin` |
| `curl`         | any     | Pre-installed on most distros                                                   |
| `make`         | any     | `sudo apt install make`                                                         |

> **Linux kernel requirement** — SonarQube requires `vm.max_map_count >= 524288`. If the container exits with an Elasticsearch error, run:
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> # Make it permanent:
> echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
> ```

---

## Quick Start

```bash
# 1. Clone / navigate to this project
cd code-gate

# 2. Start SonarQube (first start pulls ~600 MB of images)
make start

# 3. First-time setup — changes the default admin password and generates a token
#    Run once after SonarQube becomes ready (≈ 60–90 seconds)
make setup

# 4. Analyze any project on your machine
make analyze DIR=/home/user/my-project

# 5. Open the dashboard
make open
# or visit http://localhost:9020
```

---

## Detailed Usage

### Starting and Stopping

```bash
make start      # start containers in background
make stop       # stop containers (data is preserved)
make restart    # restart only the SonarQube container
make status     # print current system status
make logs       # stream SonarQube logs (Ctrl+C to exit)
```

### Running an Analysis

```bash
# Minimum — project key is derived from the directory name
make analyze DIR=/path/to/project

# Custom key and name
make analyze DIR=/path/to/project KEY=my-backend NAME="My Backend API"

# Using the script directly
./scripts/analyze.sh -p /path/to/project -k my-backend -n "My Backend API"
```

After the scan finishes, the terminal prints a direct link to the project dashboard:

```
View results: http://localhost:9020/dashboard?id=my-backend
```

### Project-Level Configuration

Run `make init` to auto-detect the project language and generate a ready-to-use `sonar-project.properties`:

```bash
make init DIR=/path/to/project
```

The script detects the language from marker files (`pom.xml`, `go.mod`, `package.json`, etc.) and writes the correct coverage properties for that language. Review the generated file, generate your coverage report, then run the analysis:

```bash
make analyze DIR=/path/to/project
```

Alternatively, copy and edit the full template manually:

```bash
cp config/sonar-project.properties.template /path/to/project/sonar-project.properties
```

---

## Ignoring Test Files

SonarQube treats test files separately from production code. You can control this behavior in `sonar-project.properties`:

```properties
# Tell SonarQube which directories contain test code
sonar.tests=src/test

# Exclude tests from quality metrics (code smells, duplication, complexity)
# but still allow coverage reporting
sonar.coverage.exclusions=**/test/**,**/__tests__/**,**/*Test.*,**/*.test.*,**/*.spec.*

# Exclude test files completely from all analysis
# Use this if you do NOT want any test-related results in the dashboard
sonar.exclusions=**/test/**,**/__tests__/**,**/*.test.*,**/*.spec.*
```

Use `sonar.coverage.exclusions` to keep coverage reporting while hiding test files from quality metrics. Use `sonar.exclusions` to ignore them entirely.

---

## Code Coverage

SonarQube does **not** generate coverage on its own — it reads a report produced by your test tool. The flow is:

```
your test tool → generates report → sonar-scanner reads it → displays in dashboard
```

### Step 1 — Generate the coverage report

**JavaScript / TypeScript (Jest)**
```bash
jest --coverage --coverageReporters=lcov
# output: coverage/lcov.info
```

**Python (pytest-cov)**
```bash
pip install pytest-cov
pytest --cov=src --cov-report=xml
# output: coverage.xml
```

**Java (Maven + JaCoCo)**

Add to `pom.xml`:
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
# output: target/site/jacoco/jacoco.xml
```

**Go**
```bash
go install github.com/jandelgado/gcov2lcov@latest
go test ./... -coverprofile=coverage.out
gcov2lcov -infile=coverage.out -outfile=coverage.lcov
# output: coverage.out
```

**PHP (PHPUnit)**

Add to `phpunit.xml`:
```xml
<coverage>
  <report>
    <clover outputFile="coverage/clover.xml"/>
  </report>
</coverage>
```
```bash
./vendor/bin/phpunit --coverage-clover coverage/clover.xml
# output: coverage/clover.xml
```

### Step 2 — Point the report in `sonar-project.properties`

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

### Step 3 — Run the analysis

```bash
make analyze DIR=/path/to/project
```

> The coverage panel only appears after SonarQube receives at least one valid report. If the report file is missing, the scanner silently skips it — confirm the file was generated before running `make analyze`.

---

## File Structure

```
code-gate/
├── scripts/
│   ├── analyze.sh                          # Analysis runner
│   ├── init-project.sh                     # Project config generator
│   └── setup.sh                            # First-time setup helper
├── config/
│   ├── docker-compose.yml                  # SonarQube + PostgreSQL services
│   └── sonar-project.properties.template  # Project config template
├── docs/
│   ├── README.es.md                        # Spanish translation
│   └── README.pt-br.md                     # Portuguese (BR) translation
├── .env.example                            # Environment variable reference
├── .gitignore
├── Makefile                                # Convenience commands
└── README.md                               # This file (English)
```

---

## Environment Variables

| Variable                   | Default                 | Description                                                |
| -------------------------- | ----------------------- | ---------------------------------------------------------- |
| `SONARQUBE_URL`            | `http://localhost:9020` | SonarQube base URL                                         |
| `SONARQUBE_TOKEN`          | _(empty)_               | Auth token — generated by `make setup` and saved to `.env` |
| `SONARQUBE_ADMIN_PASSWORD` | `Admin@12345678`        | Admin password set during `make setup`                     |

Variables are read from `.env` automatically by `analyze.sh`. Copy `.env.example` to `.env` to customize.

---

## Makefile Reference

| Command                   | Description                                 |
| ------------------------- | ------------------------------------------- |
| `make start`              | Start SonarQube and PostgreSQL              |
| `make stop`               | Stop all containers                         |
| `make restart`            | Restart SonarQube container                 |
| `make setup`              | First-time setup (password + token)         |
| `make init DIR=<path>`    | Generate sonar-project.properties for a project |
| `make analyze DIR=<path>` | Run analysis on a project                   |
| `make logs`               | Stream SonarQube logs                       |
| `make status`             | Print system status JSON                    |
| `make open`               | Open dashboard in browser                   |
| `make clean`              | **Destroy all data** (containers + volumes) |

---

## Troubleshooting

### SonarQube container exits immediately

Check kernel settings:

```bash
make logs
# If you see "max virtual memory areas vm.max_map_count [...] is too low":
sudo sysctl -w vm.max_map_count=524288
```

### Container name already in use

A previous container was not properly removed. Run:

```bash
docker rm -f sonarqube sonarqube_db
make start
```

### "SonarQube is not running or not ready"

Wait for the health check to pass (~90 seconds on the first start):

```bash
make status   # keep running until you see "status":"UP"
```

### Token or authentication errors

Re-run setup to generate a fresh token:

```bash
make setup
```

### Port 9020 already in use

Edit `config/docker-compose.yml` and change `"9020:9000"` to e.g. `"9021:9000"`, then update `.env`:

```
SONARQUBE_URL=http://localhost:9021
```

### Coverage not showing in the dashboard

- Confirm the report file was generated before running `make analyze`
- Check that the path in `sonar-project.properties` matches the actual output file
- Re-run the analysis after fixing the path

---

## Recommended Pre-PR Workflow

1. Finish your feature branch.
2. Generate the coverage report with your test tool.
3. Run `make analyze DIR=<your-project>`.
4. Fix any **Blocker** or **Critical** issues shown in the dashboard.
5. Open the PR only after the Quality Gate passes (green).

---

## License

This project is released under the [MIT License](LICENSE).  
SonarQube Community Edition is licensed under the [GNU LGPL v3](https://www.gnu.org/licenses/lgpl-3.0.html).
