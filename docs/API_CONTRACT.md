# Contrato de API

Este repositório front-end serve como a fonte oficial de verdade para a API.
Qualquer alteração na API (endpoints, request/response bodies, parâmetros, etc.)
feita pelo frontend ou backend deverá ser atualizada em `openapi.yaml`.

A documentação da API usa a especificação OpenAPI 3.1.x e pode ser encontrada em `openapi.yaml`.

## Atualização e Leitura
- O arquivo `openapi.yaml` serve para ser lido e verificado por ferramentas automáticas,
  como o Spectral, e deve ser usado como guia pelo agente do backend.
- Não existem cópias independentes deste arquivo no repositório backend. O agente do backend
  deve consultá-lo diretamente daqui (através do GitHub).
- Sempre que houver um novo requisito funcional do front-end que impacte a API,
  o arquivo `openapi.yaml` será atualizado em conjunto com o código Dart.

## Status de Implementação (x-implementation-status)
- `required`: Endpoint desenhado ou necessário, mas ainda não foi possível confirmar
   a implementação no backend.
- `implemented`: Implementação visível ou verificada no código do backend, mas pode
   faltar testes.
- `verified`: Testada e funcionando.

## Endpoints Mapeados
O frontend já se comunica ou vai se comunicar com:
- `POST /oauth2/token`
- `POST /auth/google`
- `POST /users`
- `GET /users/me`
- `PUT /users/me/profile`
- `POST /users/me/password`
- `GET /notifications/my`
- `PATCH /notifications/{id}/read`
- `GET /memberships/my`
- `GET /condominiums/{id}`
- `GET /condominiums/{id}/announcements`
- `GET /condominiums/{id}/common-areas`
- `POST /common-areas/{id}/reservations`
- `PATCH /reservations/{id}/cancel`
- `PUT /manager/condominiums/{id}/units/{unitId}/payment-status`
- `GET /admin/dashboard`
- `POST /admin/system-announcements`
- `PATCH /packages/{id}/{action}`
- `POST /packages`

Para cada alteração neste documento, certifique-se de validar usando as regras padrão de OpenAPI.
