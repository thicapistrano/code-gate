# CODE-GATE - Analisador de Código Local com SonarQube

Execute uma análise completa do SonarQube em qualquer projeto local antes de abrir um PR — encontre vulnerabilidades, code smells, bugs e duplicações sem subir uma única linha de código.

> Traduções: [English](../README.md) · [Español](README.es.md)

---

## Como Funciona

```
Seu projeto local
       │
       ▼
  analyze.sh          ← monta o diretório do projeto no container sonar-scanner-cli
       │
       ▼
 SonarQube (Docker)   ← persiste os resultados no PostgreSQL
       │
       ▼
  Dashboard no browser ← http://localhost:9020
```

1. **Docker Compose** sobe o SonarQube Community + PostgreSQL localmente na porta `9020`.
2. **`analyze.sh`** inicia a imagem oficial `sonar-scanner-cli` do Docker, monta seu projeto e envia os resultados para o SonarQube.
3. Você revisa os problemas encontrados no dashboard antes de criar o PR.

---

## Pré-requisitos

| Ferramenta     | Versão   | Observação                                                                     |
| -------------- | -------- | ------------------------------------------------------------------------------ |
| Docker         | 20+      | [Instalar Docker](https://docs.docker.com/get-docker/)                         |
| Docker Compose | v2+      | Incluído no Docker Desktop; no Linux: `sudo apt install docker-compose-plugin` |
| `curl`         | qualquer | Pré-instalado na maioria das distros                                           |
| `make`         | qualquer | `sudo apt install make`                                                        |

> **Requisito do kernel Linux** — o SonarQube exige `vm.max_map_count >= 524288`. Se o container parar com erro do Elasticsearch, execute:
>
> ```bash
> sudo sysctl -w vm.max_map_count=524288
> # Para tornar permanente:
> echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
> ```

---

## Início Rápido

```bash
# 1. Navegue até este projeto
cd code-gate

# 2. Suba o SonarQube (na primeira vez baixa ~600 MB de imagens)
make start

# 3. Setup inicial — altera a senha padrão do admin e gera um token
#    Execute uma vez após o SonarQube estar pronto (≈ 60–90 segundos)
make setup

# 4. Analise qualquer projeto da sua máquina
make analyze DIR=/home/usuario/meu-projeto

# 5. Abra o dashboard
make open
# ou acesse http://localhost:9020
```

---

## Uso Detalhado

### Iniciar e Parar

```bash
make start      # inicia os containers em background
make stop       # para os containers (os dados são preservados)
make restart    # reinicia apenas o container do SonarQube
make status     # exibe o status atual do sistema
make logs       # acompanha os logs do SonarQube (Ctrl+C para sair)
```

### Executando uma Análise

```bash
# Mínimo — a chave do projeto é derivada do nome do diretório
make analyze DIR=/caminho/para/projeto

# Com chave e nome personalizados
make analyze DIR=/caminho/para/projeto KEY=meu-backend NAME="Meu Backend API"

# Usando o script diretamente
./scripts/analyze.sh -p /caminho/para/projeto -k meu-backend -n "Meu Backend API"
```

Ao finalizar, o terminal exibe o link direto para o dashboard do projeto:

```
View results: http://localhost:9020/dashboard?id=meu-backend
```

### Configuração por Projeto

Execute `make init` para detectar automaticamente a linguagem do projeto e gerar um `sonar-project.properties` pronto para uso:

```bash
make init DIR=/caminho/para/projeto
```

O script detecta a linguagem pelos arquivos do projeto (`pom.xml`, `go.mod`, `package.json`, etc.) e escreve as propriedades de cobertura corretas para ela. Revise o arquivo gerado, gere o relatório de cobertura e execute a análise:

```bash
make analyze DIR=/caminho/para/projeto
```

Ou copie e edite o template completo manualmente:

```bash
cp config/sonar-project.properties.template /caminho/para/projeto/sonar-project.properties
```

---

## Ignorando Arquivos de Teste

O SonarQube trata arquivos de teste separadamente do código de produção. Você pode controlar esse comportamento no `sonar-project.properties`:

```properties
# Informa ao SonarQube quais diretórios contêm código de teste
sonar.tests=src/test

# Exclui testes das métricas de qualidade (code smells, duplicação, complexidade)
# mas mantém o relatório de cobertura
sonar.coverage.exclusions=**/test/**,**/__tests__/**,**/*Test.*,**/*.test.*,**/*.spec.*

# Exclui arquivos de teste completamente de toda a análise
# Use isso se NÃO quiser nenhum resultado relacionado a testes no dashboard
sonar.exclusions=**/test/**,**/__tests__/**,**/*.test.*,**/*.spec.*
```

Use `sonar.coverage.exclusions` para manter o relatório de cobertura mas ocultar os testes das métricas de qualidade. Use `sonar.exclusions` para ignorá-los completamente.

---

## Cobertura de Código

O SonarQube **não gera** cobertura por conta própria — ele lê um relatório produzido pela sua ferramenta de testes. O fluxo é:

```
sua ferramenta de teste → gera relatório → sonar-scanner lê → exibe no dashboard
```

### Passo 1 — Gere o relatório de cobertura

**JavaScript / TypeScript (Jest)**
```bash
jest --coverage --coverageReporters=lcov
# saída: coverage/lcov.info
```

**Python (pytest-cov)**
```bash
pip install pytest-cov
pytest --cov=src --cov-report=xml
# saída: coverage.xml
```

**Java (Maven + JaCoCo)**

Adicione ao `pom.xml`:
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
# saída: target/site/jacoco/jacoco.xml
```

**Go**
```bash
go install github.com/jandelgado/gcov2lcov@latest
go test ./... -coverprofile=coverage.out
gcov2lcov -infile=coverage.out -outfile=coverage.lcov
# saída: coverage.out
```

**PHP (PHPUnit)**

Adicione ao `phpunit.xml`:
```xml
<coverage>
  <report>
    <clover outputFile="coverage/clover.xml"/>
  </report>
</coverage>
```
```bash
./vendor/bin/phpunit --coverage-clover coverage/clover.xml
# saída: coverage/clover.xml
```

### Passo 2 — Aponte o relatório no `sonar-project.properties`

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

### Passo 3 — Execute a análise

```bash
make analyze DIR=/caminho/para/projeto
```

> O painel de cobertura só aparece após o SonarQube receber pelo menos um relatório válido. Se o arquivo de relatório não existir no caminho configurado, o scanner o ignora silenciosamente — confirme que o arquivo foi gerado antes de executar `make analyze`.

---

## Estrutura de Arquivos

```
code-gate/
├── scripts/
│   ├── analyze.sh                          # Runner de análise
│   ├── init-project.sh                     # Gerador de configuração do projeto
│   └── setup.sh                            # Helper de configuração inicial
├── config/
│   ├── docker-compose.yml                  # Serviços SonarQube + PostgreSQL
│   └── sonar-project.properties.template  # Template de configuração do projeto
├── docs/
│   ├── README.es.md                        # Tradução em espanhol
│   └── README.pt-br.md                     # Este arquivo (Português BR)
├── .env.example                            # Referência de variáveis de ambiente
├── .gitignore
├── Makefile                                # Comandos de conveniência
└── README.md                               # Inglês
```

---

## Variáveis de Ambiente

| Variável                   | Padrão                  | Descrição                                                          |
| -------------------------- | ----------------------- | ------------------------------------------------------------------ |
| `SONARQUBE_URL`            | `http://localhost:9020` | URL base do SonarQube                                              |
| `SONARQUBE_TOKEN`          | _(vazio)_               | Token de autenticação — gerado pelo `make setup` e salvo no `.env` |
| `SONARQUBE_ADMIN_PASSWORD` | `Admin@12345678`        | Senha do admin definida durante o `make setup`                     |

As variáveis são lidas automaticamente do arquivo `.env` pelo `analyze.sh`. Copie `.env.example` para `.env` para personalizar.

---

## Referência do Makefile

| Comando                      | Descrição                                       |
| ---------------------------- | ----------------------------------------------- |
| `make start`                 | Inicia o SonarQube e o PostgreSQL               |
| `make stop`                  | Para todos os containers                        |
| `make restart`               | Reinicia o container do SonarQube               |
| `make setup`                 | Setup inicial (senha + token)                   |
| `make init DIR=<caminho>`    | Gera o sonar-project.properties para um projeto |
| `make analyze DIR=<caminho>` | Executa a análise em um projeto                 |
| `make logs`                  | Acompanha os logs do SonarQube                  |
| `make status`                | Exibe o status do sistema em JSON               |
| `make open`                  | Abre o dashboard no browser                     |
| `make clean`                 | **Apaga todos os dados** (containers + volumes) |

---

## Solução de Problemas

### Container do SonarQube para imediatamente

Verifique as configurações do kernel:

```bash
make logs
# Se aparecer "max virtual memory areas vm.max_map_count [...] is too low":
sudo sysctl -w vm.max_map_count=524288
```

### Nome de container já em uso

Um container anterior não foi removido corretamente. Execute:

```bash
docker rm -f sonarqube sonarqube_db
make start
```

### "SonarQube is not running or not ready"

Aguarde o health check passar (~90 segundos na primeira inicialização):

```bash
make status   # repita até ver "status":"UP"
```

### Erros de token ou autenticação

Reexecute o setup para gerar um novo token:

```bash
make setup
```

### Porta 9020 já em uso

Edite `config/docker-compose.yml` e mude `"9020:9000"` para ex. `"9021:9000"`, depois atualize o `.env`:

```
SONARQUBE_URL=http://localhost:9021
```

### Cobertura não aparece no dashboard

- Confirme que o arquivo de relatório foi gerado antes de executar `make analyze`
- Verifique se o caminho no `sonar-project.properties` corresponde ao arquivo gerado
- Execute a análise novamente após corrigir o caminho

---

## Fluxo Recomendado Pré-PR

1. Finalize sua feature branch.
2. Gere o relatório de cobertura com sua ferramenta de testes.
3. Execute `make analyze DIR=<seu-projeto>`.
4. Corrija todos os problemas do tipo **Blocker** ou **Critical** exibidos no dashboard.
5. Abra o PR somente após o Quality Gate passar (verde).

---

## Licença

Este projeto é distribuído sob a [Licença MIT](../LICENSE).  
O SonarQube Community Edition é licenciado sob a [GNU LGPL v3](https://www.gnu.org/licenses/lgpl-3.0.html).
