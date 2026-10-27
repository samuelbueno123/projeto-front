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

Os endpoints existentes foram confirmados por leitura dos serviços e telas
Dart deste frontend. O backend não foi inspecionado nem executado nesta
alteração. Por isso, as operações mantêm status `required`; nenhuma é declarada
implementada ou verificada no backend.

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
- Administração: `GET /admin/dashboard`, `GET /admin/data/{resource}`,
  `GET /admin/search` e `POST /admin/system-announcements`.
- Listas de apoio usadas pela navegação: `GET /billing/plans`, `GET /sectors`,
  `GET /units` e `GET /residents`.

Essas operações são requisitos do frontend e ainda dependem de confirmação e
compatibilização com o backend. Os formatos de resposta refletem os campos que
as telas leem; qualquer divergência observada durante a integração deve ser
resolvida junto com uma atualização deste contrato.

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
