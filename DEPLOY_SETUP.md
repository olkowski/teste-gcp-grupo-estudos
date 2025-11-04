# Setup para Deploy na GCP

Este documento contém as instruções para configurar o deploy automático da aplicação Quarkus no Google Cloud Platform (GCP) usando GitHub Actions.

## Pré-requisitos

1. Conta no Google Cloud Platform
2. Projeto GCP criado
3. Repositório GitHub configurado

## Configuração do Google Cloud Platform

### 1. Habilitar APIs necessárias

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### 2. Criar Artifact Registry

```bash
gcloud artifacts repositories create teste-gcp-grupo-estudos \
    --repository-format=docker \
    --location=us-central1 \
    --description="Docker repository para teste-gcp-grupo-estudos"
```

### 3. Configurar Workload Identity Federation

#### 3.1 Criar um pool de identidade

```bash
gcloud iam workload-identity-pools create "github-pool" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool"
```

#### 3.2 Criar um provedor de identidade

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --display-name="GitHub Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"
```

#### 3.3 Criar Service Account

```bash
gcloud iam service-accounts create "github-actions-sa" \
    --project="${PROJECT_ID}" \
    --display-name="GitHub Actions Service Account"
```

#### 3.4 Conceder permissões necessárias

```bash
# Cloud Run Admin
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/run.admin"

# Artifact Registry Writer
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

# Service Account User
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"
```

#### 3.5 Permitir que o GitHub acesse a Service Account

```bash
gcloud iam service-accounts add-iam-policy-binding \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/olkowski/teste-gcp-grupo-estudos" \
    github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

## Configuração dos Secrets no GitHub

Acesse as configurações do seu repositório GitHub: `Settings` > `Secrets and variables` > `Actions`

### Secrets necessários:

1. **GCP_PROJECT_ID**: ID do seu projeto GCP
   ```
   Nome: GCP_PROJECT_ID
   Valor: seu-projeto-id
   ```

2. **WIF_PROVIDER**: Provider do Workload Identity
   ```
   Nome: WIF_PROVIDER
   Valor: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider
   ```

3. **WIF_SERVICE_ACCOUNT**: Email da Service Account
   ```
   Nome: WIF_SERVICE_ACCOUNT
   Valor: github-actions-sa@seu-projeto-id.iam.gserviceaccount.com
   ```

### Secrets opcionais (usam valores padrão se não definidos):

4. **GAR_LOCATION**: Localização do Artifact Registry (padrão: us-central1)
   ```
   Nome: GAR_LOCATION
   Valor: us-central1
   ```

5. **GCP_REGION**: Região para deploy no Cloud Run (padrão: us-central1)
   ```
   Nome: GCP_REGION
   Valor: us-central1
   ```

## Como obter o PROJECT_NUMBER

Execute o comando:
```bash
gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)"
```

## Testando o Deploy

1. Faça um commit e push para a branch `main`
2. Verifique a execução da pipeline em `Actions` no GitHub
3. Após o sucesso, a URL da aplicação será exibida nos logs da pipeline

## Estrutura da Pipeline

A pipeline executa os seguintes passos:

1. **Test**: Executa os testes da aplicação
2. **Build and Deploy** (apenas na branch main):
   - Autentica no GCP usando Workload Identity
   - Constrói a aplicação Java
   - Cria e publica a imagem Docker no Artifact Registry
   - Faz deploy no Cloud Run

## Monitoramento

- **Cloud Run**: https://console.cloud.google.com/run
- **Artifact Registry**: https://console.cloud.google.com/artifacts
- **Logs**: https://console.cloud.google.com/logs

## Troubleshooting

### Erro de permissões
- Verifique se todas as APIs estão habilitadas
- Confirme se a Service Account tem as permissões corretas
- Verifique se o Workload Identity está configurado corretamente

### Erro de build
- Verifique se o Dockerfile está correto
- Confirme se o Artifact Registry existe e está acessível

### Erro de deploy
- Verifique se o Cloud Run está habilitado
- Confirme se a região está correta
- Verifique se a porta 8080 está exposta corretamente