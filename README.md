# Âncora Gestão Condominial — Frontend Multiplataforma 📱💻

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg?style=flat&logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg?style=flat&logo=dart)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platforms-Web_|_Android_|_iOS-brightgreen.svg?style=flat)]()
[![Tests](https://img.shields.io/badge/Tests-38_Passed-success.svg?style=flat)]()

Interface multiplataforma do sistema **Âncora Gestão Condominial**, desenvolvida em **Flutter/Dart**. O aplicativo oferece uma experiência moderna, rápida e consistente para **moradores**, **porteiros**, **síndicos** e **administradores globais**, operando em navegadores web e dispositivos móveis (Android e iOS).

---

## 🏗️ Arquitetura e Organização de Pastas

O projeto adota a arquitetura **Feature-First (orientada a funcionalidades)**, garantindo modularidade, facilidade de manutenção e isolamento de responsabilidades:

```
lib/
├── core/                                # Módulos transversais e infraestrutura
│   ├── config/                          # Configurações globais e URLs de API (api_config.dart)
│   ├── http/                            # Cliente HTTP com Correlation ID, retries e tratamento de erros
│   │   ├── api_exception.dart           # Hierarquia de exceções com correlationId e displayMessage
│   │   ├── api_response.dart            # Wrapper de respostas da API
│   │   └── http_client_wrapper.dart     # Cliente com retentativa (503/504) e injeção de headers
│   ├── services/                        # Serviços centrais (RealtimeService SSE, Storage)
│   └── ui/                              # SaaS Design System e componentes reutilizáveis
│       └── saas_design_system.dart      # LoadingState, EmptyState, ErrorState, DataCard, MetricGrid
│
├── features/                            # Módulos de negócio da aplicação
│   ├── auth/                            # Login local (OAuth2), Google Sign-In, cadastro e recuperação
│   ├── admin/                           # Painel administrativo global (condomínios, planos, métricas)
│   ├── manager/                         # Painel do síndico (aprovação de membros, finanças, assembleias)
│   ├── doorman/                         # Operação da portaria (encomendas, controle de acessos, chat)
│   ├── community/                       # Hub comunitário (SOS Pânico, QR Pass, Obras NBR 16.280, Achados)
│   └── home/                            # Dashboard inicial do morador, reservas e comunicados
│
└── main.dart                            # Ponto de entrada e roteamento inicial
```

---

## 🎨 SaaS Design System e Experiência do Usuário

A interface implementa um sistema visual consistente e responsivo projetado para aplicações corporativas SaaS:

- **Estados Padronizados de Tela:**
  - `SaaSLoadingState`: Indicadores elegantes de carregamento com mensagens contextuais.
  - `SaaSEmptyState`: Telas vazias ilustradas com título, descrição e botão de ação direta.
  - `SaaSErrorState`: Banners e cartões informativos de falha com opção de retentativa e exibição do código de rastreamento do erro (`correlationId`).
- **Cards e Métricas Responsivas:**
  - `SaaSDataCard`: Componentes de dados com badge de status, metadados e ações rápidas.
  - `SaaSMetricGrid`: Grade responsiva para dashboards executivos e operacionais.
- **Busca por Enter (`EnterSearchField`):**
  - Pesquisa eficiente acionada apenas quando o usuário confirma com Enter, economizando requisições e melhorando a fluidez.

---

## 🛡️ Resiliência HTTP e Rastreabilidade

O [`HttpClientWrapper`](lib/core/http/http_client_wrapper.dart) possui proteções automáticas de nível de produção:

1. **Correlation ID Automático:** Cada chamada HTTP gera um cabeçalho único `X-Correlation-ID: req-...`.
2. **Retentativa Automática com Backoff:** Operações idempotentes (`GET`, `PUT`, `DELETE`) executam até 2 retentativas sob códigos de instabilidade temporária (`503`, `504`) ou falhas transitórias de conexão.
3. **Código de Rastreamento ao Usuário:** Quando ocorre um erro na API, a mensagem de erro inclui o código de correlação gerado pelo servidor (`Código de rastreamento: <id>`), permitindo que moradores e síndicos reportem o código exato ao suporte técnico.

---

## ⚙️ Variáveis de Ambiente e Execução

As variáveis de build são passadas via `--dart-define`:

| Variável | Descrição | Valor Padrão Local |
|:---|:---|:---|
| `API_BASE_URL` | URL base do backend Spring Boot | `http://localhost:8080` |
| `GOOGLE_WEB_CLIENT_ID` | Client ID Web do Google Identity Services | Client ID corporativo |

### Execução no Navegador Web (Chrome)
```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

### Execução no Emulador Android
No emulador Android, a máquina host é acessível pelo IP virtual `10.0.2.2`:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

---

## 🧪 Testes Automatizados

O frontend conta com testes unitários de serviços HTTP, validação de formulários, controle de papéis e renderização de widgets do Design System:

```bash
# Executa todos os testes (38 testes)
flutter test

# Executa teste específico de resiliência e Correlation ID
flutter test test/http_client_wrapper_test.dart

# Análise estática do código
flutter analyze
```

---

## 📦 Build para Produção

```bash
# Build otimizado para Web (distribuível estático para Nginx ou S3)
flutter build web --release --dart-define=API_BASE_URL=https://api.condominio.com

# Build para Android (APK)
flutter build apk --release --dart-define=API_BASE_URL=https://api.condominio.com
```
