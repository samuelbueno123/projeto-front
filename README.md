# Projeto Front

## Login com Google

O login exige configuração no projeto do Google Cloud que pertence ao backend:

1. Crie um cliente OAuth **Android** com o package name configurado em
   `android/app/build.gradle.kts` (`com.example.projeto_front`).
2. Cadastre a impressão digital SHA-1 do certificado que assina o APK. Para o
   build de desenvolvimento, obtenha-a com:

   ```bash
   ./gradlew signingReport
   ```

3. Configure também o cliente OAuth correspondente para cada certificado de
   release usado na distribuição.
4. Inicie o app apontando para uma URL que o dispositivo consiga alcançar. Em
   emulador Android, o backend na máquina de desenvolvimento normalmente é
   `http://10.0.2.2:3000`, e não `http://localhost:3000`:

   ```bash
   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
   ```

O app declara a permissão `INTERNET` no manifesto principal, portanto o fluxo
também funciona em builds de release. Se a configuração OAuth estiver ausente,
a tela de login apresenta uma mensagem específica em vez de ocultar a causa em
um erro genérico.
