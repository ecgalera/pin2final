name: Terraform Deployment

on:
  workflow_dispatch: # Esto permite ejecutar el workflow manualmente desde la UI de GitHub

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout repository
      uses: actions/checkout@v2

    - name: Set up Terraform
      uses: hashicorp/setup-terraform@v1
      with:
        terraform_version: 1.0.0

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Terraform Init
      run: terraform init

    - name: Terraform Apply
      run: terraform apply -auto-approve -var key_name=${{ secrets.KEY_NAME }}

