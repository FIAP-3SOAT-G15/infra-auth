# IaC for Auth

IaC para usar pool do Cognito e funções Lambda de autenticação provisionada com Terraform.

Repositório principal: [tech-challenge](https://github.com/FIAP-3SOAT-G15/tech-challenge)

## Recursos criados

User pool do Cognito com grupos para clientes e administradores, funções Lambda para sign up e sign in de clientes, e função que define auth challenge como trigger de autenticação customizada no Cognito (com CPF ou e-mail e senha).

## Estrutura

```text
.
├── .github/
│   └── workflows/
│       └── provisioning.yml  # provisionamento de IaC com Terraform
└── terraform/                # IaC com Terraform
```
