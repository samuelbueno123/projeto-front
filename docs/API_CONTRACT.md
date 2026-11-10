# Contrato Oficial da API — Âncora Gestão Condominial

> **Especificação OpenAPI:** [`openapi.yaml`](openapi.yaml) (OpenAPI 3.1.0)  
> **Status:** Sincronizado e Verificado em Produção  
> **Última Atualização:** Novembro de 2026  

Este documento define o contrato oficial de integração entre o frontend Flutter (`projeto-front`) e o backend Spring Boot (`projeto-final`), registrando os padrões de comunicação, cabeçalhos, tratamento de erros e o catálogo completo de endpoints verificados por testes automatizados.

---

## 1. Padrões Globais de Integração

1. **Protocolo e Formato:** Comunicação REST via HTTP/1.1 com payloads em `application/json; charset=UTF-8` (exceto `/oauth2/token`, que utiliza `application/x-www-form-urlencoded`).
2. **Rastreabilidade com Correlation ID (`X-Correlation-ID`):**
   - O frontend gera e anexa o cabeçalho `X-Correlation-ID: req-<timestamp_hex>-<sequence_hex>` em todas as requisições disparadas pelo `HttpClientWrapper`.
   - O backend preserva esse identificador no contexto MDC e o reflete nos cabeçalhos de resposta HTTP (`X-Correlation-ID`).
   - Em caso de erro, a propriedade `correlationId` é extraída e disponibilizada para o usuário através de `ApiException.displayMessage`.
3. **Resiliência e Retentativa Automática:**
   - Requisições HTTP idempotentes (`GET`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`) executam até **2 retentativas automáticas com backoff linear** caso o servidor retorne `503 Service Unavailable`, `504 Gateway Timeout` ou desconexões transitórias (`ClientException`).
   - Requisições não-idempotentes (`POST`, `PATCH`) não realizam retentativa automática sem confirmação explícita.
4. **Tratamento Padronizado de Erros:**
   - Respostas de erro retornam o payload unificado `StandardError` ou `ValidationError` contendo `timestamp`, `status`, `error`, `message`, `path` e `correlationId`.

---

## 2. Catálogo de Chamadas Implementadas e Verificadas

### 2.1. Autenticação e Sessão
- `POST /oauth2/token`: Autenticação por email e senha via OAuth2 Password Grant (retorna JWT e refresh token).
- `POST /auth/google`: Validação de Google ID Token e emissão de sessão própria da plataforma.
- `GET /.well-known/jwks.json`: Chaves públicas RSA (2048 bits) para validação do JWT.

### 2.2. Usuários e Conta
- `POST /users`: Cadastro de usuário público ou administrativo (com atribuição de roles).
- `GET /users/me`: Perfil completo do usuário logado e suas permissões ativas.
- `PUT /users/me/profile`: Atualização de nome e imagem de perfil (avatar).
- `POST /users/me/password`: Alteração de senha com prova da senha atual ou token Google recente.
- `GET /media/pictures/{fileName}`: Download da imagem de perfil servida pelo backend.

### 2.3. Condomínios e Membresias
- `GET /memberships/my`: Consulta todos os condomínios aos quais o usuário logado pertence.
- `POST /memberships/request`: Solicitação de vinculação de um morador a uma unidade.
- `GET /manager/condominiums/{id}/membership-requests`: Lista solicitações pendentes de moradores.
- `POST /manager/condominiums/{id}/membership-requests/{id}/approve`: Aprovação pelo síndico.
- `POST /manager/condominiums/{id}/membership-requests/{id}/reject`: Rejeição pelo síndico.
- `GET /condominiums`: Listagem paginada de condomínios.
- `GET /condominiums/{id}`: Detalhes do condomínio.
- `POST /condominiums`: Cadastro de novo condomínio (`ROLE_ADMIN`).
- `GET /condominiums/{id}/directory`: Lista telefônica e diretório de contatos úteis do condomínio.
- `GET /condominiums/{id}/gallery` e `POST /condominiums/{id}/gallery`: Galeria de fotos institucionais.

### 2.4. Estrutura Física: Setores, Unidades e Moradores
- `GET /sectors` e `POST /sectors`: Gestão de blocos e torres.
- `GET /units` e `POST /units`: Gestão de apartamentos e unidades habitacionais.
- `GET /residents` e `POST /residents`: Vínculo formal de proprietários e inquilinos à unidade.

### 2.5. Áreas Comuns e Reservas
- `GET /common-areas`: Consulta de espaços de uso comum (churrasqueiras, salões).
- `POST /common-areas/{id}/reservations`: Criação de reserva com controle de concorrência pessimista (`PESSIMISTIC_WRITE`) e opção de fila de espera.
- `POST /common-areas/{id}/waitlist`: Inclusão direta na fila de espera para datas concorridas.
- `GET /condominiums/{id}/reservations/my`: Minhas reservas ativas e histórico.
- `PATCH /reservations/{id}/approve`: Aprovação manual pelo síndico.
- `PATCH /reservations/{id}/cancel`: Cancelamento de reserva com promoção automática da fila de espera.

### 2.6. Encomendas e Armários Inteligentes (Smart Lockers)
- `GET /packages`: Listagem de encomendas da unidade ou da portaria.
- `POST /packages`: Registro de recebimento na portaria com disparo de evento SSE.
- `PATCH /packages/{id}/status`: Transição de estado (`RECEIVED` -> `READY_FOR_PICKUP` -> `DELIVERED`).
- `GET /condominiums/{id}/smart-lockers`: Consulta de compartimentos disponíveis e ocupados.
- `POST /condominiums/{id}/smart-lockers/deposit`: Alocação da encomenda com geração de PIN.
- `POST /condominiums/{id}/smart-lockers/pickup`: Retirada de encomenda via autoatendimento informando PIN.

### 2.7. Financeiro, Despesas e Boletos
- `GET /condominiums/{id}/financial/expenses`: Lista despesas condominiais com comprovantes.
- `POST /condominiums/{id}/financial/expenses`: Registro de nova despesa pelo síndico.
- `GET /condominiums/{id}/financial/invoices`: Faturas e cobranças das unidades.
- `POST /condominiums/{id}/financial/invoices/generate-boleto`: Emissão de boleto com código de barras e Pix.
- `POST /condominiums/{id}/financial/invoices/{id}/pay`: Confirmação simulada de pagamento.

### 2.8. Manutenções e Ordens de Serviço
- `GET /condominiums/{id}/maintenance`: Ordens de serviço preventivas e corretivas.
- `POST /condominiums/{id}/maintenance`: Abertura de chamado de manutenção com fotos.
- `PATCH /maintenance/{id}/status`: Atualização do status (`PENDING`, `IN_PROGRESS`, `COMPLETED`).

### 2.9. Assembleias Virtuais e Votações
- `GET /condominiums/{id}/assemblies`: Assembleias convocadas e em andamento.
- `POST /condominiums/{id}/assemblies`: Convocação com pautas de deliberação.
- `POST /assemblies/{id}/vote`: Voto formal com apuração ponderada por fração ideal.

### 2.10. Comunidade, Portaria e Segurança
- `GET /condominiums/{id}/lost-found` e `POST /condominiums/{id}/lost-found`: Achados e perdidos com mural.
- `POST /lost-found/{id}/messages`: Mensagens privativas entre quem encontrou e o dono.
- `GET /condominiums/{id}/visitors` e `POST /condominiums/{id}/visitors`: Passes de visitantes com QR Code e link WhatsApp.
- `PATCH /visitors/{id}/check-in`: Registro de entrada de visitante na guarita.
- `POST /condominiums/{id}/visitors/validate-qr`: Validação instantânea de passe por leitor de QR Code.
- `POST /condominiums/{id}/emergency/panic`: Acionamento prioritário do botão SOS/Pânico.
- `GET /condominiums/{id}/renovations` e `POST /condominiums/{id}/renovations`: Aprovação de obras sob a norma ABNT NBR 16.280.
- `GET /condominiums/{id}/polls` e `POST /condominiums/{id}/polls/vote`: Enquetes de opinião comunitárias.

### 2.11. Comunicação e Streaming em Tempo Real (SSE)
- `GET /condominiums/{id}/doorman-chat/messages`: Histórico de mensagens entre portaria e morador.
- `POST /condominiums/{id}/doorman-chat/messages`: Envio de mensagem instantânea.
- `GET /realtime/stream?condominiumId={id}`: Conexão contínua Server-Sent Events (`text/event-stream`).

### 2.12. Observabilidade e Health Check (Actuator)
- `GET /actuator/health`: Status operacional do banco, memória JVM, disco e ping.
- `GET /actuator/health/liveness` e `/readiness`: Probes para orquestradores de contêineres.
- `GET /actuator/info`: Metadados da versão e runtime.
- `GET /actuator/metrics`: Métricas de autenticações, reservas, encomendas e SOS (`ROLE_ADMIN`).
