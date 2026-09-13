# AWS Secure Infrastructure Automation

## Overview

AWS Secure Infrastructure Automation is a hands-on DevSecOps project that demonstrates how secure AWS infrastructure can be provisioned and managed using Infrastructure as Code and CI/CD automation.

The project uses Terraform to define AWS infrastructure and GitHub Actions to automate validation, security scanning, planning, and deployment.

Security is integrated throughout the project through IAM role separation, GitHub OIDC authentication, Trivy Infrastructure as Code scanning, encrypted storage, Terraform remote state, IMDSv2, and AWS Systems Manager.

The project was designed to demonstrate practical experience with cloud security, infrastructure automation, CI/CD, and DevSecOps principles.

## Technologies

The project uses the following technologies:

- Amazon Web Services (AWS)
- Terraform
- GitHub
- GitHub Actions
- GitHub OIDC
- AWS Identity and Access Management (IAM)
- Amazon EC2
- Amazon VPC
- Amazon S3
- AWS Systems Manager
- Trivy
- PowerShell
- Git

## AWS Infrastructure

Terraform provisions and manages the AWS infrastructure used by the project.

The infrastructure includes:

- Amazon VPC
- Public subnet
- Internet Gateway
- Route table
- Route table association
- Security group
- Amazon EC2 instance
- IAM role
- IAM instance profile
- AWS Systems Manager permissions

The EC2 instance uses Amazon Linux 2023.

Infrastructure configuration is stored inside the `terraform` directory of the repository.

## Infrastructure as Code

Terraform is used to define AWS infrastructure as code.

This allows infrastructure changes to be reviewed, validated, scanned, and deployed using the same Git-based workflow used for application development.

Terraform manages networking, compute, IAM, security groups, storage configuration, and instance security settings.

## Security Controls

Security was incorporated into both the AWS infrastructure and CI/CD pipelines.

### No Public SSH Access

The EC2 instance does not expose SSH port 22 to the internet.

The security group contains no inbound rules.

Administrative access to the EC2 instance is performed using AWS Systems Manager Session Manager instead of SSH.

This removes the requirement for SSH keys and prevents an administrative port from being publicly exposed.

### Restricted Outbound Traffic

The EC2 security group restricts outbound traffic to HTTPS on TCP port 443.

This allows the instance to communicate with required AWS services while reducing unnecessary outbound network access.

### IMDSv2

The EC2 instance requires Instance Metadata Service Version 2.

The Terraform configuration includes:

```hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

Requiring IMDSv2 provides additional protection when applications access EC2 instance metadata.

### Encrypted EBS Storage

The EC2 root volume is encrypted and uses gp3 storage.

```hcl
root_block_device {
  encrypted   = true
  volume_type = "gp3"
}
```

### AWS Systems Manager

AWS Systems Manager Session Manager is used for administrative access to the EC2 instance.

The EC2 instance receives the required permissions through an IAM role and instance profile using the `AmazonSSMManagedInstanceCore` managed policy.

This allows administrative access without opening inbound SSH access.

## GitHub OIDC Authentication

GitHub Actions authenticates to AWS using OpenID Connect.

No long-lived AWS access keys are stored in GitHub Secrets for the CI/CD pipelines.

GitHub Actions receives an OIDC token that AWS validates before allowing the workflow to assume an IAM role.

AWS then provides temporary credentials to the workflow.

This reduces the security risks associated with storing permanent cloud credentials inside a CI/CD platform.

## IAM Role Separation

Continuous Integration and Continuous Deployment use separate AWS IAM roles.

### CI Role

The `GitHubActions-Terraform-Role` is used by the Continuous Integration pipeline.

The CI role is primarily responsible for reading infrastructure information and allowing Terraform to generate deployment plans.

It does not have the same infrastructure modification permissions as the deployment role.

### Deployment Role

The `GitHubActions-Terraform-Deploy-Role` is used by the Continuous Deployment pipeline.

This role contains the permissions required for Terraform to modify the AWS resources managed by the project.

Separating CI and deployment permissions reduces the privileges available to routine CI operations.

## Continuous Integration

The CI workflow is located at:

```text
.github/workflows/terraform.yml
```

The workflow runs automatically when changes are pushed to the main branch.

The pipeline performs the following operations:

1. Checks out the repository.
2. Configures Terraform.
3. Checks Terraform formatting.
4. Runs a Trivy Infrastructure as Code security scan.
5. Authenticates to AWS using GitHub OIDC when required.
6. Initializes Terraform.
7. Validates the Terraform configuration.
8. Generates a Terraform plan.

The CI pipeline allows infrastructure changes to be evaluated before they are deployed.

## Infrastructure Security Scanning

Trivy is integrated into the GitHub Actions CI pipeline to scan Terraform configuration for security misconfigurations.

The pipeline is configured to fail when HIGH or CRITICAL findings violate the project's security gate.

During development, Trivy identified security concerns involving unrestricted outbound traffic and the public subnet configuration.

Outbound access was restricted to HTTPS.

Where a security recommendation conflicted with the design requirements of the lab, the exception was documented directly in the Terraform configuration.

For example:

```hcl
# Lab exception: outbound HTTPS is required for AWS Systems Manager.
# Production design would use private VPC endpoints for SSM.
#trivy:ignore:AWS-0104
```

This project uses a risk-based approach in which findings are remediated when practical and required exceptions are explicitly documented.

## Terraform Remote State

Terraform state is stored remotely using Amazon S3.

The S3 backend provides a centralized state file that can be accessed by authorized Terraform workflows.

The state bucket is configured with:

- Block Public Access
- Bucket versioning
- Server-side encryption
- Terraform state locking
- IAM-controlled access

Terraform uses the following state key:

```text
devsecops/terraform.tfstate
```

Native S3 state locking is enabled using:

```hcl
use_lockfile = true
```

Remote state allows local Terraform operations and GitHub Actions workflows to use the same infrastructure state.

## Continuous Deployment

The deployment workflow is located at:

```text
.github/workflows/terraform-deploy.yml
```

Unlike the CI pipeline, infrastructure deployment does not occur automatically after every push.

Deployment is manually initiated using GitHub Actions.

The deployment process requires the workflow to run against the main branch and requires the user to enter:

```text
APPLY
```

The workflow uses the GitHub `production` environment and assumes the dedicated AWS deployment role through OIDC.

The deployment workflow performs:

1. Repository checkout.
2. Terraform setup.
3. AWS authentication using GitHub OIDC.
4. AWS identity verification.
5. Terraform initialization.
6. Terraform validation.
7. Terraform plan generation.
8. Terraform apply.

This separates automated testing from privileged infrastructure deployment.

## End-to-End Deployment Validation

The complete CI/CD pipeline was tested using a real Terraform infrastructure modification.

The following tag was added to the EC2 instance:

```hcl
Deployment = "GitHub-Actions-CD"
```

The Terraform change was committed and pushed to the main branch.

The CI pipeline automatically validated and scanned the updated configuration.

The deployment workflow was then manually executed using the production environment and dedicated deployment IAM role.

Terraform detected the EC2 tag modification as an in-place infrastructure change and successfully applied it.

The resulting EC2 instance contained:

```text
Deployment = GitHub-Actions-CD
```

This test validated the complete workflow from source code modification through CI security checks and controlled deployment into AWS.

## Repository Structure

The repository is organized into the following primary components:

```text
AWS-Secure-Infrastructure-Automation/

.github/
    workflows/
        terraform.yml
        terraform-deploy.yml

terraform/
    main.tf
    providers.tf
    .terraform.lock.hcl

.gitignore
README.md
```

Terraform state files, Terraform variable files, credentials, private keys, environment files, and local Terraform working directories are excluded from source control using `.gitignore`.

## DevSecOps Concepts Demonstrated

This project demonstrates hands-on experience with:

- Infrastructure as Code
- Terraform
- AWS infrastructure automation
- CI/CD pipelines
- GitHub Actions
- GitHub OIDC
- Short-lived AWS credentials
- IAM role separation
- Least-privilege access
- Infrastructure security scanning
- Security gates
- Terraform remote state
- Terraform state locking
- Secure EC2 administration
- AWS Systems Manager
- Git-based infrastructure workflows
- Automated AWS deployments
- Cloud security configuration
- Troubleshooting IAM permissions

## Challenges and Lessons Learned

Several issues encountered during development provided practical troubleshooting experience.

### IAM Permissions

Terraform initially encountered AWS `AccessDenied` errors when required IAM actions were missing.

Instead of assigning broad administrative permissions, the denied AWS API actions were identified and the required permissions were added to the appropriate project roles.

### GitHub OIDC

GitHub Actions initially failed to assume the AWS IAM role because the OIDC trust relationship did not match the repository's subject claim.

The trust relationship was corrected to use the appropriate GitHub OIDC subject information.

### CI and Deployment Role Separation

Separate roles were configured for CI and deployment.

During configuration, permissions and trust relationships had to be verified to ensure each workflow assumed the correct role.

This reinforced the importance of separating infrastructure inspection privileges from infrastructure deployment privileges.

### Terraform State Migration

Terraform state was migrated from local state storage to an Amazon S3 backend.

The project now uses centralized, encrypted, versioned remote state with state locking.

### Trivy Security Findings

Trivy identified HIGH and CRITICAL infrastructure findings during development.

The findings were reviewed individually.

Security configurations were modified where appropriate, while intentional lab exceptions were documented directly in the Terraform code.

### CI/CD Deployment Testing

The final deployment pipeline was validated by making a Terraform-managed EC2 tag change and deploying it through GitHub Actions.

This confirmed that the complete CI/CD workflow could securely modify AWS infrastructure.

## Future Improvements

Future versions of the project may include:

- AWS CloudTrail
- Amazon CloudWatch monitoring
- VPC Flow Logs
- Private subnet architecture
- VPC endpoints for AWS Systems Manager
- Additional policy-as-code controls
- GitHub Actions dependency pinning
- Dependabot
- Automated lab environment cleanup
- Additional monitoring and alerting

## Author

Evan Youssef

Cybersecurity professional focused on cloud security, automation, and DevSecOps.

Certifications:

- CompTIA Security+
- AWS Certified Cloud Practitioner

