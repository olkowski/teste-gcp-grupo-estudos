#!/bin/bash

# Script para configuração inicial do GCP para deploy via GitHub Actions
# Execute este script após fazer login no gcloud: gcloud auth login

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Configurando GCP para deploy via GitHub Actions${NC}"

# Verificar se está logado no gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 > /dev/null; then
    echo -e "${RED}❌ Erro: Você precisa estar logado no gcloud. Execute: gcloud auth login${NC}"
    exit 1
fi

# Obter PROJECT_ID atual
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Erro: Nenhum projeto configurado. Execute: gcloud config set project SEU_PROJECT_ID${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Projeto atual: ${PROJECT_ID}${NC}"

# Obter PROJECT_NUMBER
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo -e "${YELLOW}📋 Project Number: ${PROJECT_NUMBER}${NC}"

# Definir variáveis
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"
SERVICE_ACCOUNT_NAME="github-actions-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
REPOSITORY_NAME="teste-gcp-grupo-estudos"
LOCATION="us-central1"
GITHUB_REPO="olkowski/teste-gcp-grupo-estudos"

echo -e "${GREEN}1️⃣ Habilitando APIs necessárias...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable iam.googleapis.com

echo -e "${GREEN}2️⃣ Criando Artifact Registry...${NC}"
if ! gcloud artifacts repositories describe $REPOSITORY_NAME --location=$LOCATION &>/dev/null; then
    gcloud artifacts repositories create $REPOSITORY_NAME \
        --repository-format=docker \
        --location=$LOCATION \
        --description="Docker repository para $REPOSITORY_NAME"
    echo -e "${GREEN}✅ Artifact Registry criado${NC}"
else
    echo -e "${YELLOW}⚠️ Artifact Registry já existe${NC}"
fi

echo -e "${GREEN}3️⃣ Criando Workload Identity Pool...${NC}"
if ! gcloud iam workload-identity-pools describe $POOL_NAME --location=global &>/dev/null; then
    gcloud iam workload-identity-pools create $POOL_NAME \
        --project=$PROJECT_ID \
        --location=global \
        --display-name="GitHub Actions Pool"
    echo -e "${GREEN}✅ Workload Identity Pool criado${NC}"
else
    echo -e "${YELLOW}⚠️ Workload Identity Pool já existe${NC}"
fi

echo -e "${GREEN}4️⃣ Criando Workload Identity Provider...${NC}"
if ! gcloud iam workload-identity-pools providers describe $PROVIDER_NAME --workload-identity-pool=$POOL_NAME --location=global &>/dev/null; then
    gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME \
        --project=$PROJECT_ID \
        --location=global \
        --workload-identity-pool=$POOL_NAME \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
        --issuer-uri="https://token.actions.githubusercontent.com"
    echo -e "${GREEN}✅ Workload Identity Provider criado${NC}"
else
    echo -e "${YELLOW}⚠️ Workload Identity Provider já existe${NC}"
fi

echo -e "${GREEN}5️⃣ Criando Service Account...${NC}"
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &>/dev/null; then
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --project=$PROJECT_ID \
        --display-name="GitHub Actions Service Account"
    echo -e "${GREEN}✅ Service Account criada${NC}"
else
    echo -e "${YELLOW}⚠️ Service Account já existe${NC}"
fi

echo -e "${GREEN}6️⃣ Concedendo permissões...${NC}"

# Cloud Run Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/run.admin" \
    --quiet

# Artifact Registry Writer
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/artifactregistry.writer" \
    --quiet

# Service Account User
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/iam.serviceAccountUser" \
    --quiet

echo -e "${GREEN}7️⃣ Configurando Workload Identity...${NC}"
gcloud iam service-accounts add-iam-policy-binding \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO" \
    $SERVICE_ACCOUNT_EMAIL \
    --quiet

echo -e "${GREEN}✅ Configuração concluída!${NC}"
echo
echo -e "${YELLOW}📋 Secrets para configurar no GitHub:${NC}"
echo
echo -e "${GREEN}GCP_PROJECT_ID:${NC} $PROJECT_ID"
echo -e "${GREEN}WIF_PROVIDER:${NC} projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/providers/$PROVIDER_NAME"
echo -e "${GREEN}WIF_SERVICE_ACCOUNT:${NC} $SERVICE_ACCOUNT_EMAIL"
echo -e "${GREEN}GAR_LOCATION:${NC} $LOCATION (opcional)"
echo -e "${GREEN}GCP_REGION:${NC} $LOCATION (opcional)"
echo
echo -e "${YELLOW}🔗 Configure estes secrets em: https://github.com/$GITHUB_REPO/settings/secrets/actions${NC}"
echo
echo -e "${GREEN}🎉 Pronto! Agora você pode fazer push para a branch main e ver o deploy automático em ação!${NC}"