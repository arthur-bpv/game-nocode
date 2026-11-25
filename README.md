# NETBOT — servidor multiplayer LAN

A branch `main-server` contém o backend dedicado do NETBOT, separado a partir
do commit `66db8b4` da branch `feat/multiplayer-lan`. O cliente Godot continua
na branch de multiplayer.

## Conteúdo

- `server/`: serviço Go, autenticação SUAP, salas, simulação, testes,
  migrações PostgreSQL e configuração Docker Compose/Caddy.
- `data/lan/inspection.json`: geometria e versão do mapa usadas pelo servidor
  e pelo cliente. Mantenha esse arquivo compatível entre as duas branches.
- `docs/multiplayer_lan.md`: implantação, operação, backup e verificação.

## Implantação

Clone esta branch no servidor:

```sh
git clone --branch main-server --single-branch git@github.com:arthur-bpv/game-nocode.git
cd game-nocode/server
umask 077
cp .env.example .env
```

Preencha `.env` com os dados do laboratório, banco e cliente OAuth SUAP.
Configure DNS, certificados HTTPS e acesso da rede conforme o
[guia de implantação](docs/multiplayer_lan.md) antes de iniciar:

```sh
docker compose config --quiet
docker compose up -d --build
```

O Compose executa o proxy HTTPS, o serviço Go e o PostgreSQL. O contexto de
build é a raiz do repositório, pois a imagem também inclui o mapa JSON.

## Testes

Com Go 1.25 ou posterior e um PostgreSQL local descartável:

```sh
cd server
export NETBOT_TEST_DATABASE_URL='postgresql://usuario:senha@localhost/netbot_test?sslmode=disable'
go test -race -v ./...
```

O teste cria e remove um schema isolado e simula o provedor OAuth via HTTPS.
Sem `NETBOT_TEST_DATABASE_URL`, o teste de integração é ignorado.
