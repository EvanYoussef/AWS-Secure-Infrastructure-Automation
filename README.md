\# AWS Secure Infrastructure Automation



A hands-on DevSecOps project that demonstrates the automated deployment of secure AWS infrastructure using \*\*Terraform, GitHub Actions, AWS IAM, GitHub OIDC, Trivy, and Amazon S3 remote state\*\*.



The project implements Infrastructure as Code (IaC), automated security scanning, CI/CD pipelines, short-lived cloud authentication, remote Terraform state management, and controlled infrastructure deployments.



\---



\## Project Overview



The goal of this project is to demonstrate a secure DevSecOps workflow for provisioning and managing AWS infrastructure.



Instead of manually creating cloud resources, the infrastructure is defined using Terraform and managed through GitHub.



The project separates Continuous Integration (CI) and Continuous Deployment (CD) responsibilities using different AWS IAM roles.



\### CI Pipeline



Code pushed to the repository is automatically checked using GitHub Actions.



The CI pipeline performs:



\- Terraform formatting validation

\- Trivy Infrastructure-as-Code security scanning

\- GitHub OIDC authentication to AWS

\- Terraform initialization

\- Terraform validation

\- Terraform planning



The CI role is designed for infrastructure inspection and planning rather than deployment.



\### CD Pipeline



Infrastructure deployment is handled by a separate manually triggered GitHub Actions workflow.



Deployment requires:



1\. The workflow to run from the `main` branch

2\. Manual execution through `workflow\_dispatch`

3\. The confirmation value `APPLY`

4\. Access through the protected `production` environment

5\. Authentication to AWS using a dedicated deployment IAM role



Terraform then initializes the remote backend, validates the configuration, generates a deployment plan, and applies the approved infrastructure changes.



\---



\## Architecture



```text

Developer

&#x20;   |

&#x20;   | git push

&#x20;   v

GitHub Repository

&#x20;   |

&#x20;   +---------------------------+

&#x20;   |                           |

&#x20;   v                           v

Terraform CI                Terraform Deploy

&#x20;   |                           |

&#x20;   | fmt                       | Manual Trigger

&#x20;   | Trivy Scan                | Type "APPLY"

&#x20;   | OIDC                      | Production Environment

&#x20;   | Validate                  |

&#x20;   | Plan                      v

&#x20;   |                    GitHub OIDC

&#x20;   |                           |

&#x20;   v                           v

CI IAM Role              Deployment IAM Role

&#x20;   |                           |

&#x20;   | Read / Plan               | Deploy

&#x20;   |                           |

&#x20;   +------------+--------------+

&#x20;                |

&#x20;                v

&#x20;         Terraform Backend

&#x20;            Amazon S3

&#x20;       Remote State + Locking

&#x20;                |

&#x20;                v

&#x20;              AWS

&#x20;                |

&#x20;       +--------+---------+

&#x20;       |                  |

&#x20;      VPC                IAM

&#x20;       |

&#x20;  Public Subnet

&#x20;       |

&#x20;  Route Table

&#x20;       |

&#x20;Internet Gateway

&#x20;       |

&#x20; Security Group

&#x20;       |

&#x20;      EC2

&#x20;       |

&#x20;AWS Systems Manager

```



\---



\## AWS Infrastructure



Terraform provisions the following AWS resources:



\- Amazon VPC

\- Public subnet

\- Internet Gateway

\- Route table and subnet association

\- Security group

\- Amazon EC2 instance

\- IAM role for EC2

\- IAM instance profile

\- AWS Systems Manager permissions



The EC2 instance uses Amazon Linux 2023 and is managed entirely through Terraform.



\---



\## Security Controls



Security was incorporated throughout the infrastructure and deployment process.



\### No SSH Access



The EC2 instance does not expose SSH (TCP/22) to the internet.



Administrative access is performed through \*\*AWS Systems Manager Session Manager\*\*.



This eliminates the need to manage SSH private keys or expose an inbound administrative port.



\### No Inbound Security Group Rules



The EC2 security group contains no inbound rules.



Outbound traffic is restricted to HTTPS (TCP/443) for required AWS service communication.



\### IMDSv2



The EC2 instance requires \*\*Instance Metadata Service Version 2 (IMDSv2)\*\*:



```hcl

metadata\_options {

&#x20; http\_endpoint = "enabled"

&#x20; http\_tokens   = "required"

}

```



This requires session-oriented authentication when accessing the EC2 Instance Metadata Service.



\### Encrypted Storage



The EC2 root EBS volume is encrypted and uses `gp3` storage.



```hcl

root\_block\_device {

&#x20; encrypted   = true

&#x20; volume\_type = "gp3"

}

```



\### GitHub OIDC Authentication



GitHub Actions authenticates to AWS using \*\*OpenID Connect (OIDC)\*\* rather than storing long-lived AWS access keys in GitHub Secrets.



GitHub receives a temporary OIDC token, which AWS validates before allowing the workflow to assume the appropriate IAM role.



```text

GitHub Actions

&#x20;     |

&#x20;     | OIDC Token

&#x20;     v

AWS IAM Identity Provider

&#x20;     |

&#x20;     v

IAM Role

&#x20;     |

&#x20;     v

Temporary AWS Credentials

```



This reduces the risks associated with persistent cloud credentials in CI/CD systems.



\### Separation of CI and CD Roles



Two AWS IAM roles are used for GitHub Actions.



\*\*GitHubActions-Terraform-Role\*\*



Used by the CI pipeline for infrastructure inspection and Terraform planning.



\*\*GitHubActions-Terraform-Deploy-Role\*\*



Used by the controlled deployment pipeline and granted the permissions required to modify the project's infrastructure.



This separates routine CI operations from privileged deployment operations.



\---



\## Infrastructure Security Scanning



The CI pipeline integrates \*\*Trivy\*\* to scan Terraform configuration for security misconfigurations.



The workflow fails when HIGH or CRITICAL findings violate the configured security gate.



During development, Trivy identified infrastructure security concerns including unrestricted outbound access and public subnet configuration.



Outbound access was restricted to HTTPS, while required lab exceptions were explicitly documented in the Terraform configuration.



Example:



```hcl

\# Lab exception: outbound HTTPS is required for AWS Systems Manager.

\# Production design would use private VPC endpoints for SSM.

\#trivy:ignore:AWS-0104

```



This demonstrates a risk-based approach where security findings are remediated when possible and explicitly documented when an architectural exception is required.



\---



\## Terraform Remote State



Terraform state is stored remotely in Amazon S3 rather than only on the developer workstation.



The backend uses:



\- S3 remote state

\- S3 state locking

\- Bucket versioning

\- Server-side encryption

\- Block Public Access



Backend configuration:



```hcl

terraform {

&#x20; backend "s3" {

&#x20;   bucket       = "evanyoussef-devsecops-terraform-state-1366463268"

&#x20;   key          = "devsecops/terraform.tfstate"

&#x20;   region       = "us-east-1"

&#x20;   encrypt      = true

&#x20;   use\_lockfile = true

&#x20; }

}

```



Remote state provides a centralized source of truth for Terraform operations performed locally and through GitHub Actions.



\---



\## CI/CD Workflow



\### Continuous Integration



`.github/workflows/terraform.yml`



```text

Push / Pull Request

&#x20;       |

&#x20;       v

Terraform Format Check

&#x20;       |

&#x20;       v

Trivy IaC Scan

&#x20;       |

&#x20;       v

AWS OIDC Authentication

&#x20;       |

&#x20;       v

Terraform Init

&#x20;       |

&#x20;       v

Terraform Validate

&#x20;       |

&#x20;       v

Terraform Plan

```



HIGH and CRITICAL Trivy findings cause the security scan to fail.



AWS operations on `main` use the CI IAM role through GitHub OIDC.



\### Continuous Deployment



`.github/workflows/terraform-deploy.yml`



```text

Manual Workflow Trigger

&#x20;       |

&#x20;       v

main Branch Check

&#x20;       |

&#x20;       v

Type "APPLY"

&#x20;       |

&#x20;       v

Production Environment

&#x20;       |

&#x20;       v

AWS OIDC Authentication

&#x20;       |

&#x20;       v

Terraform Init

&#x20;       |

&#x20;       v

Terraform Validate

&#x20;       |

&#x20;       v

Terraform Plan

&#x20;       |

&#x20;       v

Terraform Apply

&#x20;       |

&#x20;       v

AWS Infrastructure

```



The deployment workflow uses a separate AWS IAM role from the CI pipeline.



\---



\## End-to-End Deployment Test



The complete pipeline was tested by adding the following Terraform-managed tag to the EC2 instance:



```hcl

Deployment = "GitHub-Actions-CD"

```



The change followed the complete workflow:



```text

Terraform Code Change

&#x20;       ↓

Git Commit / Push

&#x20;       ↓

GitHub Actions CI

&#x20;       ↓

Terraform + Trivy Validation

&#x20;       ↓

Manual Deployment

&#x20;       ↓

GitHub OIDC

&#x20;       ↓

Deployment IAM Role

&#x20;       ↓

Terraform Plan

&#x20;       ↓

Terraform Apply

&#x20;       ↓

AWS EC2 Updated

```



After deployment, the EC2 instance contained:



```text

Deployment = GitHub-Actions-CD

```



This validated that infrastructure changes could successfully move from source control through security checks and the controlled deployment pipeline into AWS.



\---



\## Technologies Used



| Technology | Purpose |

|---|---|

| AWS | Cloud infrastructure |

| Terraform | Infrastructure as Code |

| GitHub | Source control |

| GitHub Actions | CI/CD automation |

| GitHub OIDC | Short-lived AWS authentication |

| AWS IAM | Role-based access control |

| Amazon EC2 | Compute |

| Amazon VPC | Network isolation |

| AWS Systems Manager | Secure EC2 administration |

| Amazon S3 | Terraform remote state |

| Trivy | IaC security scanning |

| PowerShell | Local development and Git/Terraform operations |



\---



\## Repository Structure



```text

AWS-Secure-Infrastructure-Automation/

│

├── .github/

│   └── workflows/

│       ├── terraform.yml

│       └── terraform-deploy.yml

│

├── terraform/

│   ├── main.tf

│   ├── providers.tf

│   └── .terraform.lock.hcl

│

├── .gitignore

└── README.md

```



Terraform state, variable files, credentials, private keys, and local Terraform working directories are excluded from source control.



\---



\## Key DevSecOps Concepts Demonstrated



This project demonstrates practical experience with:



\- Infrastructure as Code

\- CI/CD automation

\- Cloud infrastructure security

\- Identity federation

\- Short-lived cloud credentials

\- IAM role separation

\- Least-privilege access design

\- Infrastructure security scanning

\- Security gates

\- Remote state management

\- State locking

\- Secure administrative access

\- Git-based infrastructure workflows

\- Automated cloud deployments



\---



\## Future Improvements



Potential improvements include:



\- AWS CloudTrail logging

\- Amazon CloudWatch monitoring

\- VPC Flow Logs

\- Private subnet architecture

\- VPC endpoints for AWS Systems Manager

\- Automated Terraform destruction for lab environments

\- GitHub Actions dependency pinning

\- Dependabot for Terraform providers and GitHub Actions

\- Additional policy-as-code security controls



\---



\## Lessons Learned



This project provided hands-on experience designing a DevSecOps workflow rather than simply provisioning AWS resources.



Key lessons included:



\- Troubleshooting IAM `AccessDenied` errors using the specific denied AWS API action

\- Configuring GitHub OIDC trust relationships

\- Understanding OIDC subject claims and trust boundaries

\- Separating CI and deployment privileges

\- Migrating Terraform state from local storage to an S3 backend

\- Implementing Terraform state locking

\- Using automated IaC security scanning as a deployment gate

\- Evaluating and documenting security exceptions

\- Using AWS Systems Manager instead of exposing SSH

\- Troubleshooting CI/CD pipelines across GitHub, Terraform, and AWS



\---



\## Author



\*\*Evan Youssef\*\*



Cybersecurity professional focused on cloud security, automation, and DevSecOps.



Certifications:



\- CompTIA Security+

\- AWS Certified Cloud Practitioner

