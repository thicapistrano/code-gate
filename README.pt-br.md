# # CODE-GATE - Analisador de Código Local com SonarQube

Execute uma análise completa do SonarQube em qualquer projeto local antes de abrir um PR — encontre vulnerabilidades, code smells, bugs e duplicações sem subir uma única linha de código.

> Traduções: [English](README.md) · [Español](README.es.md)

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
  Dashboard no browser ← http://localhost:9000
```

1. **Docker Compose** sobe o SonarQube Community + PostgreSQL localmente na porta `9000`.
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
# ou acesse http://localhost:9000
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
./analyze.sh -p /caminho/para/projeto -k meu-backend -n "Meu Backend API"
```

Ao finalizar, o terminal exibe o link direto para o dashboard do projeto:

```
View results: http://localhost:9000/dashboard?id=meu-backend
```

### Configuração por Projeto

Para controle mais fino (caminhos de testes, relatórios de cobertura, configurações por linguagem), copie o template para o projeto alvo:

```bash
cp sonar-project.properties.template /caminho/para/projeto/sonar-project.properties
# Edite o arquivo e execute a análise novamente
make analyze DIR=/caminho/para/projeto
```

---

## Estrutura de Arquivos

```
code-gate/
├── docker-compose.yml                  # Serviços SonarQube + PostgreSQL
├── analyze.sh                          # Runner de análise
├── setup.sh                            # Helper de configuração inicial
├── Makefile                            # Comandos de conveniência
├── sonar-project.properties.template  # Template de configuração do projeto
├── .env.example                        # Referência de variáveis de ambiente
├── .gitignore
├── README.md                           # Inglês
├── README.es.md                        # Espanhol
└── README.pt-br.md                     # Este arquivo (Português BR)
```

---

## Variáveis de Ambiente

| Variável                   | Padrão                  | Descrição                                                          |
| -------------------------- | ----------------------- | ------------------------------------------------------------------ |
| `SONARQUBE_URL`            | `http://localhost:9000` | URL base do SonarQube                                              |
| `SONARQUBE_TOKEN`          | _(vazio)_               | Token de autenticação — gerado pelo `make setup` e salvo no `.env` |
| `SONARQUBE_ADMIN_PASSWORD` | `Admin@123`             | Senha do admin definida durante o `make setup`                     |

As variáveis são lidas automaticamente do arquivo `.env` pelo `analyze.sh`. Copie `.env.example` para `.env` para personalizar.

---

## Referência do Makefile

| Comando                      | Descrição                                       |
| ---------------------------- | ----------------------------------------------- |
| `make start`                 | Inicia o SonarQube e o PostgreSQL               |
| `make stop`                  | Para todos os containers                        |
| `make restart`               | Reinicia o container do SonarQube               |
| `make setup`                 | Setup inicial (senha + token)                   |
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

### Porta 9000 já em uso

Edite o `docker-compose.yml` e mude `"9000:9000"` para, por exemplo, `"9001:9000"`, depois atualize o `.env`:

```
SONARQUBE_URL=http://localhost:9001
```

---

## Fluxo Recomendado Pré-PR

1. Finalize sua feature branch.
2. Execute `make analyze DIR=<seu-projeto>`.
3. Corrija todos os problemas do tipo **Blocker** ou **Critical** exibidos no dashboard.
4. Abra o PR somente após o Quality Gate passar (verde).

---

## Licença

Este projeto é distribuído sob a [Licença MIT](LICENSE).  
O SonarQube Community Edition é licenciado sob a [GNU LGPL v3](https://www.gnu.org/licenses/lgpl-3.0.html).
