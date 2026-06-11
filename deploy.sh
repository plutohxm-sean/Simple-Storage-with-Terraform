#!/bin/bash
GREEN='\033[0;32m';BLUE='\033[0;34m';YELLOW='\033[1;33m';RED='\033[0;31m';NC='\033[0m'
echo -e "${BLUE}🚀 Deploying with Terraform${NC}"
echo "================================"
if ! command -v terraform &>/dev/null; then
  echo -e "${RED}❌ Terraform not found!${NC}"
  echo "  wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip"
  echo "  unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/"
  exit 1
fi
terraform init
terraform validate || { echo -e "${RED}❌ Invalid config${NC}"; exit 1; }
terraform plan
echo -e "\n${YELLOW}⚠️  Create AWS resources?${NC}"
read -p "Continue? (y/N): " C
[[ ! $C =~ ^[Yy]$ ]] && { echo "Cancelled."; exit 0; }
terraform apply -auto-approve
if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}🎉 Done!${NC}"
  terraform output
  echo -e "\n${GREEN}🌐 $(terraform output -raw website_url)${NC}"
  echo -e "${YELLOW}⏰ Wait ~2-3 min for EC2 setup${NC}"
  echo -e "${BLUE}💡 Cleanup: terraform destroy -auto-approve${NC}"
else
  echo -e "${RED}❌ Deployment failed!${NC}"; exit 1
f
