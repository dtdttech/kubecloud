#!/usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p bash cacert curl git rsync kubectl

set -e

# Configuration
SOURCE_DIR="result"
TARGET_REPO_DIR="kubevkm_rendered"
TARGET_REPO_URL="https://github.com/dtdttech/kubevkm_rendered.git"
ARGOCD_APP_NAME="deployment"
KUBECONFIG_FILE="kubeconfig"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    print_error "Source directory $SOURCE_DIR does not exist"
    print_error "Please run 'nix build .#vkm' first"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    print_error "Kubeconfig file $KUBECONFIG_FILE not found"
    exit 1
fi

print_status "Starting VKM deployment process..."

# Step 1: Copy files to target directory
print_status "Step 1: Copying manifests to $TARGET_REPO_DIR..."
mkdir -p "$TARGET_REPO_DIR"
rsync -avL --delete --chmod=0755 "$SOURCE_DIR/" "$TARGET_REPO_DIR/"

# Count files copied
FILE_COUNT=$(find "$TARGET_REPO_DIR" -type f | wc -l)
print_success "Copied $FILE_COUNT files to $TARGET_REPO_DIR"

# Step 2: Git operations
print_status "Step 2: Committing and pushing changes..."

# Change to target directory
cd "$TARGET_REPO_DIR"

# Check if it's a git repository
if [ ! -d ".git" ]; then
    print_status "Initializing git repository..."
    git init
    git remote add origin "$TARGET_REPO_URL"
fi

# Add all files
print_status "Adding files to git..."
git add .

# Check if there are changes to commit
if git diff --quiet --cached; then
    print_warning "No changes to commit"
else
    # Commit changes
    COMMIT_MESSAGE="Update VKM manifests - $(date '+%Y-%m-%d %H:%M:%S')"
    print_status "Committing changes..."
    git commit -m "$COMMIT_MESSAGE"
    
    # Push changes
    print_status "Pushing changes to repository..."
    
    # Try to determine the default branch
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$DEFAULT_BRANCH" ]; then
        DEFAULT_BRANCH="main"  # fallback
    fi
    
    # Try pushing to main first, then master if that fails
    if git push origin "$DEFAULT_BRANCH" 2>/dev/null || git push origin main 2>/dev/null || git push origin master 2>/dev/null; then
        print_success "Changes pushed successfully"
    else
        print_error "Failed to push to remote repository"
        print_error "Please check your git remote configuration and permissions"
        exit 1
    fi
fi

# Step 3: Refresh ArgoCD application
print_status "Step 3: Refreshing ArgoCD application..."

# Set kubeconfig
export KUBECONFIG="../$KUBECONFIG_FILE"

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_warning "Cannot connect to Kubernetes cluster"
    print_warning "Skipping ArgoCD refresh - please refresh manually"
    exit 0
fi

# Check if ArgoCD is available
if ! kubectl get applications.argoproj.io "$ARGOCD_APP_NAME" -n argocd &> /dev/null; then
    print_warning "ArgoCD application $ARGOCD_APP_NAME not found"
    print_warning "Skipping ArgoCD refresh - please refresh manually"
    exit 0
fi

# Refresh ArgoCD application
print_status "Refreshing ArgoCD application $ARGOCD_APP_NAME..."
kubectl patch application "$ARGOCD_APP_NAME" -n argocd --type=merge -p '{"spec": {"sync": {"refresh": "true"}}}'

# Wait for sync to start
sleep 5

# Check sync status
print_status "Checking sync status..."
SYNC_STATUS=$(kubectl get application "$ARGOCD_APP_NAME" -n argocd -o jsonpath='{.status.sync.status}')
HEALTH_STATUS=$(kubectl get application "$ARGOCD_APP_NAME" -n argocd -o jsonpath='{.status.health.status}')

print_success "ArgoCD refresh initiated"
print_status "Sync Status: $SYNC_STATUS"
print_status "Health Status: $HEALTH_STATUS"

if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
    print_success "VKM deployment completed successfully!"
else
    print_warning "Deployment is in progress or has issues"
    print_warning "Please check ArgoCD dashboard for details"
fi

print_status "Deployment process completed!"