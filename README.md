# Projeto Front

## Login com Google

O fluxo Google usa `google_sign_in` no Android e o botão oficial Google Identity
Services na Web. Configure no Google Cloud:

1. Um cliente OAuth Android para o package name em
   `android/app/build.gradle.kts` e SHA-1 dos certificados de desenvolvimento e
   release. Use `cd android; ./gradlew signingReport` para consultar o SHA-1 de
   desenvolvimento.
2. Um cliente OAuth Web com as origens autorizadas do frontend.
3. O mesmo ID de cliente Web no frontend (`GOOGLE_WEB_CLIENT_ID`) e no backend
   (`GOOGLE_CLIENT_ID`). O backend valida assinatura, emissor, público-alvo e
   email verificado do ID token antes de emitir uma sessão própria.

Para desenvolvimento em emulador Android, a API da máquina normalmente é
acessada por `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_WEB_CLIENT_ID=seu-id-web.apps.googleusercontent.com
```

## Conta do usuário

O perfil usa `GET /users/me` e `PUT /users/me/profile`. A foto é salva no banco e
aceita PNG, JPEG ou WebP de até 1 MB. A troca de email pede reautenticação.
`POST /users/me/password` pede a senha atual para contas locais ou confirmação
Google recente para contas Google.

O login por email usa `POST /oauth2/token`; cadastro usa `POST /users`. A API
base pode ser alterada por `API_BASE_URL`. Para builds do container frontend,
configure `API_BASE_URL` e `GOOGLE_CLIENT_ID` no ambiente antes de executar o
Compose.
