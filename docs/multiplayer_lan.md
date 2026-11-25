# Multiplayer LAN do NETBOT

O cliente Godot abre o SUAP no navegador. O servidor Go recebe o retorno OAuth, emite a sessão do jogo e controla presença, posições, colisões e etapas da inspeção. PostgreSQL guarda contas, sessões e resultados. O mapa cooperativo simplificado usa `data/lan/inspection.json` em ambos os builds. Atualize a versão nesse arquivo se mudar a geometria e distribua os dois builds juntos. Nos presets de exportação Godot, inclua `data/lan/*.json` no filtro de arquivos não reconhecidos como recursos.

## Implantação no laboratório

1. Reserve o IP do host no DHCP e aponte o DNS interno para ele. Obtenha certificado com o nome do host no SAN e instale a CA de confiança nos navegadores e no sistema das estações. Para uma CA interna, configure `network/tls/certificate_bundle_override` no build Godot com o bundle PEM aprovado que inclui a CA. [Configuração de TLS do Godot](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-network-tls-certificate-bundle-override)
2. Cadastre o cliente OAuth confidencial de teste com retorno exato `https://<dns-do-laboratório>/v1/auth/callback`. Confirme com o IFRN a URL de identidade HTTPS, o campo estável retornado como string JSON, o escopo mínimo, a autenticação do token (`basic` ou `post`) e PKCE S256. Este build exige S256. Se o cadastro institucional rejeitar o retorno LAN, a TI precisa aprovar o domínio e a resolução interna antes do piloto.
3. Dentro de `server`, copie `.env.example` para `.env` com permissão 0600 e configure os valores. Gere senhas distintas para a administração do PostgreSQL e para o serviço com `openssl rand -hex 32` e a chave de identidade com `openssl rand -base64 32`. Monte `fullchain.pem` e `privkey.pem` em `TLS_DIRECTORY` com acesso restrito ao host e ao proxy. Preserve uma cópia protegida da chave de identidade junto aos procedimentos de recuperação.
4. Permita TCP 443 apenas da sub-rede aprovada. Aplique o filtro também ao tráfego encaminhado pelo Docker e verifique de uma estação autorizada e de outra rede. O Compose vincula a publicação ao endereço LAN e mantém PostgreSQL em rede privada, sem porta publicada. O serviço precisa resolver e alcançar os endpoints HTTPS do SUAP.
5. Execute `docker compose config --quiet` e `docker compose up -d --build`. Verifique `GET /healthz` e `GET /readyz` via HTTPS. A prontidão verifica o banco. Exercite o login de teste para verificar a dependência institucional. Confirme que as estações alcançam o host mesmo no Wi-Fi usado pelos alunos.
6. Informe o endereço em **Multiplayer LAN**. O cliente guarda o endereço localmente após iniciar a tentativa. Para distribuir um endereço padrão no laboratório, defina `NETBOT_LAN_URL` no ambiente do jogo.

## Operação e restauração

- O serviço aplica migrações na inicialização. Rode uma instância do servidor por banco. O estado em memória de uma sala depende da instância que a criou. Reinicie fora das partidas. O serviço marca partidas em andamento como interrompidas na inicialização e preserva desfechos confirmados. O cliente que manteve o ID da partida pode buscar o desfecho pela mesma conta enquanto a sessão estiver válida.
- A limpeza elimina tentativas após cinco minutos e sessões após oito horas. Revogar uma sessão também fecha sua conexão em jogo. Para trocar o segredo OAuth ou o certificado, atualize a configuração e recrie o serviço correspondente. O HMAC é a chave de vínculo das contas. Antes do piloto, aprove com a instituição um procedimento de migração ou revinculação para eventual substituição dessa chave. Uma troca direta cria novos vínculos de identidade.
- Defina com o IFRN contas elegíveis, responsáveis, retenção, exclusão de contas e resultados, e processo de incidente. Inclua esses prazos na política de backup. O banco guarda o vínculo pseudonimizado, apelido e resultado. O proxy vem com logs de requisições desabilitados para evitar que URLs de login apareçam em registros.
- Faça o backup a partir de `server` e restaure em uma instância isolada antes de uma atualização. O banco de restauração deve estar vazio e o usuário deve ter acesso de criação de objetos.

```sh
umask 077
docker compose exec -T db pg_dump -U netbot -d netbot -Fc > netbot.dump
docker compose exec -T db createdb -U postgres -O netbot netbot_restore
docker compose exec -T db pg_restore --exit-on-error -U netbot -d netbot_restore < netbot.dump
docker compose exec -T db psql -U netbot -d netbot_restore -c 'SELECT outcome, count(*) FROM matches GROUP BY outcome'
```

O comando de restauração acima é para um Compose isolado, sem clientes conectados. Compare também as contagens em `users` e `match_players`, valide a recuperação de um apelido de teste e descarte a cópia restaurada conforme a retenção aprovada.

## Verificação

- Para a integração automatizada, forneça `NETBOT_TEST_DATABASE_URL` apontando para um PostgreSQL local descartável e rode `go test -race -v ./...` em `server`. O teste cria um schema isolado e um provedor OAuth HTTPS simulado.
- No laboratório, use duas contas distintas na mesma versão. Crie sala, entre por código, marque pronto e comece. Percorra o mapa com WASD ou setas. O leitor lê o terminal e comunica os dados ao colega, que registra o diagnóstico. Compare os resultados, repita com abandono e confirme o progresso do Modo História e o reset local.
- Interrompa a rede de uma estação durante a partida. Verifique retomada e posição antes de 30 segundos e abandono depois de 30 segundos de ausência detectada pelo servidor. Repita após reiniciar o servidor para verificar o desfecho interrompido. Confirme negação de acesso direto ao PostgreSQL nas estações.
- Para os 30 minutos de medição, sincronize os relógios e inicie ambas as estações com `NETBOT_LAN_MEASURE=1`. Colete os eventos `rtt_ms`. Para medir movimento, use a diferença entre `remote at_ms` e `input at_ms` em estações distintas com os mesmos campos `match`, `role` e `seq`. Use os deltas das contagens cumulativas de execução em `/metrics`, acessível internamente em `netbot:8080`, para estimar o p95 da duração dos ticks. Os limites dos buckets são inclusivos e cada tick conta em um único bucket.
- Registre versão, topologia, duração, perda, p95 de RTT, p95 de movimento remoto e p95 do tick. Compare com 80, 150 e 25 ms, respectivamente. Repita com latência e perda simuladas em ambiente de teste.
