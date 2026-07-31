# Capitec Terraform Training

Training project for provisioning AWS infrastructure with Terraform, driven by
GitHub Actions. It stands up, per environment (`dev` / `int` / `prod`), a set of
S3 buckets and an [Amazon EKS](https://aws.amazon.com/eks/) cluster (with a
managed node group) inside a shared training VPC in **`af-south-1`**.

> ⚠️ This provisions real, billable AWS resources (an EKS cluster + node group
> per environment). Destroy environments you are not actively using.

## Repository layout

```
.
├── Providers.tf                # Root S3 module: provider + version constraints
├── s3.tf                       # Root S3 module: buckets (consumed by Project as module.s3)
├── project_backend/            # One-time bootstrap: creates the S3 state bucket
│   ├── main.tf                 #   aws_s3_bucket "sunkersss4-dev" (the backend store)
│   └── providers.tf
├── Project/                    # PRIMARY root module (what CI runs)
│   ├── Providers.tf            #   aws provider + backend "s3" {} (config injected at init)
│   ├── main.tf                 #   wires module.s3 (../) and module.eks
│   ├── variable.tf             #   surname/initials/resource/environment/capacity_type
│   ├── locals.tf
│   ├── outputs.tf
│   ├── modules/eks/            #   subnets, IAM roles, EKS cluster + node group
│   │   ├── eks.tf
│   │   ├── eks.locals.tf       #   per-trainee subnet (CIDR) allocation
│   │   └── variables.tf
│   └── values/                 #   backend configs, one per environment
│       ├── Dev/dev.tfbackend
│       ├── int/int.tfbackend
│       └── prod/prod.tfbackend
└── .github/workflows/          # CI/CD (see below)
```

## Prerequisites

- Terraform **`~> 1.15`** (`required_version` in `Providers.tf`)
- AWS credentials with access to the training account, region **`af-south-1`**
- The S3 state bucket (`sunkersss4-dev`) must exist — bootstrap it once from
  `project_backend/` if it does not.

## Environments & remote state

State is stored in S3 (bucket `sunkersss4-dev`), one key per environment, with
native S3 locking (`use_lockfile = true`):

| Environment | State key                  | Backend config                 |
| ----------- | -------------------------- | ------------------------------ |
| `dev`       | `dev/terraform.tfstate`    | `values/Dev/dev.tfbackend`     |
| `int`       | `int/terraform.tfstate`    | `values/int/int.tfbackend`     |
| `prod`      | `prod/terraform.tfstate`   | `values/prod/prod.tfbackend`   |

Every resource is keyed by `var.environment` so the three environments coexist
without name collisions. Because all trainees share one VPC and this trainee is
allocated only three `/24`s, the EKS module carves each `/24` into `/26`s and
hands one block per environment to each availability zone
(`dev → x.x.x.0/26`, `int → x.x.x.64/26`, `prod → x.x.x.128/26`).

## Running locally

All commands run from the `Project/` directory. Pick the environment via the
matching `-backend-config` and `TF_VAR_environment`.

```bash
cd Project

# dev
terraform init -reconfigure -backend-config=values/Dev/dev.tfbackend
TF_VAR_environment=dev terraform plan
TF_VAR_environment=dev terraform apply

# int / prod: swap the backend config and the variable
terraform init -reconfigure -backend-config=values/int/int.tfbackend
TF_VAR_environment=int terraform apply
```

Useful variables (see `Project/variable.tf`):

| Variable        | Default    | Notes                                            |
| --------------- | ---------- | ------------------------------------------------ |
| `environment`   | `dev`      | Drives resource names, CIDRs and the state key   |
| `capacity_type` | `SPOT`     | Node group capacity — `ON_DEMAND` or `SPOT`      |

```bash
# Example: on-demand nodes
TF_VAR_environment=dev terraform apply -var="capacity_type=ON_DEMAND"
```

If a run is interrupted and leaves a stale lock:

```bash
terraform force-unlock <LOCK_ID>
```

## CI/CD (GitHub Actions)

| Workflow                     | Triggers                                   | Purpose                                   |
| ---------------------------- | ------------------------------------------ | ----------------------------------------- |
| `terraform-validate.yml`     | every push & pull request                  | `fmt` + `init -backend=false` + `validate` (no AWS creds) |
| `terraform-plan.yml`         | pull request, push to `main`, manual       | `init` + `validate` + `plan` (read-only, `-lock=false`)   |
| `terraform-apply.yml`        | push to `main` only                        | `init` + `validate` + `apply`             |

### Environment selection

`plan` and `apply` act on a **single** environment chosen by the repository
variable **`TF_ENVIRONMENT`** (default `dev`). To target another environment,
set it under **Settings → Secrets and variables → Actions → Variables**:

```
TF_ENVIRONMENT = int      # or prod
```

### Required configuration

- **Secrets** (Settings → Secrets and variables → Actions → Secrets):
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- **Environments** (Settings → Environments): `dev`, `int`, `prod`. Add
  **required reviewers** to an environment to make `apply` pause for manual
  approval before it runs against that environment.

## Notes & gotchas

- **Shared VPC:** subnet CIDRs come from a fixed per-trainee allocation in
  `Project/modules/eks/eks.locals.tf`. Changing an environment's subnet size
  forces subnet replacement, which requires the EKS cluster to be torn down
  first (its ENIs pin the subnets).
- **Cost:** each environment runs a live EKS control plane + node group. Run
  `terraform destroy` for environments you are not using.
- **State keys are per environment** — never point two environments at the same
  key, or their applies will clobber each other's state.
