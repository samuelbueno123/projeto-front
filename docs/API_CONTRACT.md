# Contrato oficial da API

[`openapi.yaml`](openapi.yaml) é a fonte oficial do contrato entre o frontend e
o backend e usa OpenAPI 3.1.x. Este documento explica como mantê-lo e registra
o que foi confirmado e verificado no código do frontend e do backend.

## Atualização e integração

- Atualize `docs/openapi.yaml` na mesma alteração que introduzir ou modificar
  uma chamada de API no frontend ou no backend.
- Defina métodos, caminhos, parâmetros, autenticação, cabeçalhos, conteúdo,
  modelos de entrada e saída, respostas de sucesso e erros esperados.
- Prefira schemas, parâmetros e respostas reutilizáveis em `components`.
- O agente do backend deve consultar este arquivo diretamente no repositório
  `samuelbueno123/projeto-front`. Não mantenha uma cópia independente no
  backend.
- Use `x-implementation-status: required` para requisitos ainda não
  confirmados no backend. Use `implemented` somente com evidência no código do
  backend e `verified` somente após teste ou evidência de execução.
- Valide o YAML e a consistência OpenAPI antes de publicar mudanças.

## Evidência e status atuais

As chamadas do frontend e do backend foram implementadas e verificadas por
testes automatizados em ambos os projetos:

- Autenticação e conta: `POST /oauth2/token`, `POST /auth/google`,
  `POST /users`, `GET /users/me`, `PUT /users/me/profile` e
  `POST /users/me/password`.
- Condomínios, vínculos, áreas e reservas: `GET /memberships/my`,
  `GET /memberships`, `POST /condominiums` (exclusivo para `ROLE_ADMIN`),
  `GET /condominiums/{id}`, `GET /condominiums/{id}/common-areas`,
  `GET /condominiums/{id}/announcements`,
  `GET /condominiums/{id}/reservations/my`,
  `POST /common-areas/{id}/reservations` e
  `PATCH /reservations/{id}/cancel`.
- Notificações: `GET /notifications/my` e
  `PATCH /notifications/{id}/read`.
- Encomendas: `GET /packages`, `GET /packages/my`, `POST /packages` e
  `PATCH /packages/{id}/{action}`. O cadastro pela portaria envia o ID do
  condomínio selecionado, a descrição e, quando preenchidos, os IDs do
  destinatário e da unidade.
- Gestão do condomínio: `GET /manager/dashboard` e
  `PUT /manager/condominiums/{id}/units/{unitId}/payment-status`.
- Gestão de vínculos e convites (`x-implementation-status: verified`):
  - `GET /manager/condominiums/{condominiumId}/memberships`: lista vínculos
    (`ACTIVE` e `PENDING`) do condomínio administrado pelo síndico autenticado.
  - `POST /manager/condominiums/{condominiumId}/membership-invitations`:
    convida uma conta existente (`email`) para `ROLE_RESIDENT` ou
    `ROLE_DOORMAN`, criando vínculo `PENDING` e notificação
    `MEMBERSHIP_INVITATION` na conta do destinatário. Tanto moradores quanto
    porteiros exigem aceite explícito antes de o vínculo ficar `ACTIVE` e
    conceder acesso ao condomínio.
  - `DELETE /manager/condominiums/{condominiumId}/memberships/{membershipId}`:
    permite ao síndico remover vínculo de porteiro (`ROLE_DOORMAN`) do
    condomínio que administra, revogando o papel global `ROLE_DOORMAN` caso o
    usuário não possua outro vínculo ativo de porteiro.
  - `POST /membership-invitations/{invitationId}/accept` e
    `POST /membership-invitations/{invitationId}/decline`: exclusivos para o
    destinatário do convite (`403` para terceiros, `409` se já respondido).
- Gestão global de síndicos (`x-implementation-status: verified`):
  - `GET /admin/condominiums/{condominiumId}/managers`,
    `POST /admin/condominiums/{condominiumId}/managers` e
    `DELETE /admin/condominiums/{condominiumId}/managers/{membershipId}`:
    exclusivos para `ROLE_ADMIN`; a adição de síndico ativa o vínculo
    `ROLE_MANAGER` imediatamente e a remoção revoga o papel caso não reste
    outro condomínio administrado pelo usuário.
- Administração: `GET /admin/dashboard`, `GET /admin/data/{resource}` (com
  suporte verificado ao parâmetro opcional `query` para filtrar toda a coleção
  antes da paginação), `GET /admin/search` e
  `POST /admin/system-announcements`.
- Criação administrativa de registros com seleção de entidades pai:
  `POST /users` (respeitando `roles` quando chamado por `ROLE_ADMIN`),
  `POST /condominiums`, `POST /memberships`, `POST /sectors`, `POST /units`,
  `POST /residents`, `POST /packages`, `POST /packages/expected`,
  `POST /condominiums/{condominiumId}/announcements`,
  `POST /condominiums/{condominiumId}/common-areas`,
  `POST /common-areas/{commonAreaId}/reservations` (com `reservedById` opcional
  para `ROLE_ADMIN`), `POST /billing/plans` e `POST /billing/features`.
- Listas de apoio usadas pela navegação: `GET /billing/plans`, `GET /sectors`,
  `GET /units` e `GET /residents`.

## Escopo das pesquisas por Enter

- Todas as barras de pesquisa nas telas de listagem usam `EnterSearchField` e
  só disparam o filtro quando a pessoa pressiona Enter (ou ação de busca do
  teclado).
- Nas telas de morador, notificações, portaria, painel do síndico e gestão de
  vínculos, a busca por Enter filtra os registros já carregados pela tela.
- Na tela de administração (`AdminPage`), a pesquisa global usa
  `GET /admin/search?query=...` e a pesquisa por coleção usa
  `GET /admin/data/{resource}?query=...`, filtrando todos os registros da
  coleção no backend antes de paginar.

## Autenticação e erros

- `POST /oauth2/token` usa `application/x-www-form-urlencoded` e autenticação
  Basic configurada no cliente. Esse fluxo retorna tokens de sessão próprios.
- `POST /auth/google` recebe o ID token Google em JSON, sem enviar o token de
  sessão como credencial da chamada. A API valida o ID token e retorna uma
  sessão própria.
- As demais operações protegidas usam `Authorization: Bearer <token>`.
- O cliente trata `401` e `403` como erros de autenticação/autorização,
  `404` como recurso inexistente, outros `4xx` como erros do cliente e `5xx`
  como falhas do servidor, lendo `message`, `error`, `errors`, `detail` ou
  `msg`.

## URLs canônicas

- OpenAPI: `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/openapi.yaml`
- Esta documentação: `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/API_CONTRACT.md`
