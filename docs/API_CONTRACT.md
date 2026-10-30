# Contrato de API Oficial

Este repositório front-end serve como a **fonte oficial de verdade** para a API do projeto Condomínio App.
Toda alteração na API (endpoints, parâmetros, cabeçalhos, corpos de requisição e respostas)
deve ser mantida e publicada em `docs/openapi.yaml`.

O arquivo de contrato utiliza a especificação **OpenAPI 3.1.x**.

---

## URLs Oficiais de Consulta (Branch `main`)

- **OpenAPI 3.1 Contract (YAML):**
  `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/openapi.yaml`

- **Documentação do Contrato (Markdown):**
  `https://raw.githubusercontent.com/samuelbueno123/projeto-front/main/docs/API_CONTRACT.md`

---

## Diretrizes de Consulta e Manutenção para o Agente de Backend

1. **Fonte Única:** O backend não deve manter cópias locais ou submódulos independentes do contrato. O agente de backend deve consultar diretamente as URLs da branch `main` ou este repositório.
2. **Status de Implementação (`x-implementation-status`):**
   - `required`: Endpoint necessário ao funcionamento do frontend.
   - `implemented`: Implementação encontrada no código do backend.
   - `verified`: Implementação testada e confirmada por testes automatizados ou integração.
3. **Erros e Validações:**
   - Respostas de erro devem retornar mensagens amigáveis em JSON no formato `{"message": "..."}` ou lista de validações `{"errors": [{"fieldName": "...", "message": "..."}]}`.
   - Erros de autenticação/autorização devem retornar código HTTP `401 Unauthorized` ou `403 Forbidden`.
4. **Autenticação:**
   - Suporte a OAuth2 Password Flow (`POST /oauth2/token`) utilizando HTTP Basic Auth com as credenciais de cliente OAuth.
   - Suporte a Google Sign-In (`POST /auth/google`) validando o `idToken` do Google.
   - Requisições protegidas exigem o cabeçalho `Authorization: Bearer <token_jwt>`.

---

## Endpoints Mapeados no Frontend

### Autenticação & Usuários
- `POST /oauth2/token` — Autenticação via Email/Senha
- `POST /auth/google` — Autenticação via Google Sign-In
- `POST /users` — Cadastrar novo usuário
- `GET /users/me` — Obter dados do perfil do usuário autenticado
- `PUT /users/me/profile` — Atualizar perfil (nome, email, foto, reautenticação)
- `POST /users/me/password` — Alterar senha da conta
- `GET /residents` — Listar moradores do sistema

### Condomínios & Estrutura
- `GET /memberships/my` — Listar participações do usuário logado (morador, síndico, portaria)
- `GET /memberships` — Listar todos os vínculos (painel administrativo)
- `GET /condominiums/{id}` — Obter detalhes do condomínio
- `GET /condominiums/{id}/announcements` — Listar comunicados do condomínio
- `GET /condominiums/{id}/common-areas` — Listar áreas comuns do condomínio
- `GET /sectors` — Listar setores do condomínio
- `GET /units` — Listar unidades habitacionais

### Reservas & Áreas Comuns
- `POST /common-areas/{id}/reservations` — Reservar área comum
- `GET /condominiums/{id}/reservations/my` — Listar reservas do morador no condomínio
- `PATCH /reservations/{id}/cancel` — Cancelar reserva existente

### Encomendas (Portaria & Morador)
- `GET /packages/my` — Listar encomendas do morador logado
- `GET /packages` — Listar encomendas por condomínio (painel da portaria)
- `POST /packages` — Registrar recebimento de nova encomenda
- `PATCH /packages/{id}/{action}` — Atualizar status do pacote (`receive`, `cancel`, `notify`, `pickup`, `return`)

### Painel do Síndico
- `GET /manager/dashboard` — Obter métricas, lista de pagamentos e agendamentos do condomínio
- `PUT /manager/condominiums/{id}/units/{unitId}/payment-status` — Atualizar status financeiro e vencimento da unidade

### Painel Administrativo Geral
- `GET /admin/dashboard` — Resumo e totais globais do aplicativo
- `GET /admin/data/{resource}` — Consulta paginada às coleções administrativas
- `GET /admin/search` — Busca global por nome de usuário, condomínio ou setor
- `POST /admin/system-announcements` — Criar e transmitir aviso geral para todos os usuários
- `GET /billingplans` — Listar planos de cobrança do sistema

### Notificações
- `GET /notifications/my` — Listar notificações do usuário
- `PATCH /notifications/{id}/read` — Marcar notificação como lida

---

## Validação do Contrato
O contrato é validado automaticamente através da ferramenta **Spectral CLI**:
```bash
npx @stoplight/spectral-cli lint docs/openapi.yaml
```
