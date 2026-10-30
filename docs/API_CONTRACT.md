# Contrato oficial da API

[`openapi.yaml`](openapi.yaml) é a fonte oficial do contrato entre o frontend e
o backend e usa OpenAPI 3.1.x. Este documento explica como mantê-lo e registra
o que foi confirmado no código do frontend. A presença de uma operação neste
contrato não comprova que ela exista no backend.

## Atualização e integração

- Atualize `docs/openapi.yaml` na mesma alteração que introduzir ou modificar
  uma chamada de API no frontend.
- Defina métodos, caminhos, parâmetros, autenticação, cabeçalhos, conteúdo,
  modelos de entrada e saída, respostas de sucesso e erros esperados.
- Prefira schemas, parâmetros e respostas reutilizáveis em `components`.
- O agente do backend deve consultar este arquivo diretamente na branch
  `main` do repositório `samuelbueno123/projeto-front`. Não mantenha uma cópia
  independente no backend.
- Use `x-implementation-status: required` para requisitos ainda não
  confirmados no backend. Use `implemented` somente com evidência no código do
  backend e `verified` somente após teste ou evidência de execução.
- Valide o YAML e a consistência OpenAPI antes de publicar mudanças.

## Evidência e status atuais

As chamadas do frontend foram confirmadas pelo código Dart. Também foram
inspecionados os controladores atuais de vínculos, notificações e pesquisa do
backend. O backend atual permite CRUD genérico de vínculos por ID e permite
listar/marcar notificações como lidas, mas não oferece convites, aceite/recusa,
gestão de papéis com escopo por condomínio, nem o filtro `query` nas listas
administrativas. Nenhuma dessas capacidades novas é declarada implementada.

Chamadas confirmadas no frontend:

- Autenticação e conta: `POST /oauth2/token`, `POST /auth/google`,
  `POST /users`, `GET /users/me`, `PUT /users/me/profile` e
  `POST /users/me/password`.
- Condomínios, vínculos, áreas e reservas: `GET /memberships/my`,
  `GET /memberships`, `GET /condominiums/{id}`,
  `GET /condominiums/{id}/common-areas`,
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
- Gestão: `GET /manager/dashboard` e
  `PUT /manager/condominiums/{id}/units/{unitId}/payment-status`.
- Gestão de vínculos proposta: `GET /manager/condominiums/{condominiumId}/memberships`,
  `POST /manager/condominiums/{condominiumId}/membership-invitations`,
  `DELETE /manager/condominiums/{condominiumId}/memberships/{membershipId}`,
  `POST /membership-invitations/{invitationId}/accept` e
  `POST /membership-invitations/{invitationId}/decline`.
- Gestão global de síndicos proposta: `GET` e `POST`
  `/admin/condominiums/{condominiumId}/managers`, além de
  `DELETE /admin/condominiums/{condominiumId}/managers/{membershipId}`.
- Administração: `GET /admin/dashboard`, `GET /admin/data/{resource}`,
  `GET /admin/search` e `POST /admin/system-announcements`.
- Listas de apoio usadas pela navegação: `GET /billing/plans`, `GET /sectors`,
  `GET /units` e `GET /residents`.

As operações propostas de convite e gestão de papéis, assim como o parâmetro
`query` em `/admin/data/{resource}`, têm `x-implementation-status: required` e
dependem de implementação no backend. A tela de conta sem condomínio restringe
o uso do app ao aviso de vínculo, notificações, perfil e saída. O aceite ou a
recusa ocorre a partir da notificação, com autorização limitada ao destinatário
do convite. As telas não usam o CRUD genérico de vínculos para conceder papéis.

As buscas nas listas usam os registros carregados pela tela e só aplicam o
filtro quando a pessoa pressiona Enter. A pesquisa global do painel já usa
`GET /admin/search`; o filtro remoto por coleção usa o novo parâmetro documentado
acima e precisa de suporte do backend para pesquisar além da página carregada.

## Autenticação e erros

- `POST /oauth2/token` usa `application/x-www-form-urlencoded` e autenticação
  Basic configurada no cliente. Esse fluxo retorna tokens de sessão próprios.
- `POST /auth/google` recebe o ID token Google em JSON, sem enviar o token de
  sessão como credencial da chamada. A API valida o ID token e pode retornar
  uma sessão própria.
- As demais operações protegidas usam `Authorization: Bearer <token>`.
- O cliente trata `401` e `403` como erros de autenticação/autorização,
  `404` como recurso inexistente, outros `4xx` como erros do cliente e `5xx`
  como falhas do servidor. A mensagem pode vir em `message`, `error`,
  `errors`, `detail` ou `msg`; o formato final deve ser confirmado com o
  backend.

## URLs canônicas

- OpenAPI: `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/openapi.yaml`
- Esta documentação: `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/API_CONTRACT.md`
