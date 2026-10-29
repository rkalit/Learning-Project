# Service Discovery Lab: Consul + Nginx on AWS

A hands-on lab that builds a small service-discovery setup on AWS. Terraform provisions the infrastructure, Ansible configures the servers, and Consul keeps a live registry of healthy backends that the Nginx load balancer reads automatically.

Based on the [DevOpsCube service discovery tutorial](https://devopscube.com/service-discovery-example/) and the [techiescamp/devops-projects](https://github.com/techiescamp/devops-projects) repo, reworked to use Terraform modules, Ansible roles, templated variables, and a generated inventory instead of manual steps.

---

## Servers

| Role | Count | Runs |
|---|---|---|
| Consul server | 1 | Consul in server mode, UI on port 8500 |
| Backends | 2 | Nginx + Consul agent, registered as service `backend` |
| Load balancer | 1 | Nginx + consul-template + Consul agent |

All four are `t3.micro` instances (2 vCPU, 1 GiB RAM) running Ubuntu 22.04 in a single public subnet in `ap-southeast-3` (Jakarta). `t2.micro` is not offered in that region.

---

## Project structure

```
service-discovery
├── README.md
├── ansible
│   ├── group_vars
│   │   └── all.yml
│   ├── inventory.ini
│   ├── main.yml
│   └── roles
│       ├── backends
│       ├── consul_repo
│       ├── consul_server
│       └── load_balancer
├── scripts
│   └── generate-inventory.sh
└── terraform
    ├── backend.tf
    ├── main.tf
    ├── modules
    │   ├── ec2
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variables.tf
    │   └── vpc
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf
    ├── outputs.tf
    ├── provider.tf
    ├── terraform.tfvars
    └── varibales.tf
```

---

## Prerequisites

- An AWS account and the AWS CLI configured
- IAM Role to be used by Terraform
- Terraform and Ansible installed locally
- `jq` (used by the script to generate inventory)
- An SSH key pair on your laptop (the public key is uploaded to EC2 by Terraform)
- Outbound internet from the instances (they are in a public subnet, so this works out of the box)

---

## Setup

### 1. AWS credentials (assume-role pattern)

Terraform authenticates through a named profile that assumes an IAM role, so no real permissions live on the access key itself.

`~/.aws/credentials`
```ini
[terra-lab]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

`~/.aws/config`
```ini
[profile terraform-lab]
role_arn = arn:aws:iam::<ACCOUNT_ID>:role/terraform-lab-role
source_profile = terra-lab
region = ap-southeast-3
```

- The IAM user behind `terra-lab` will only has `sts:AssumeRole` on the role.
- `terraform-lab-role` holds the VPC/EC2 permissions (or `AmazonVPCFullAccess` + `AmazonEC2FullAccess`), plus `ssm:GetParameters` on `arn:aws:ssm:ap-southeast-3::parameter/aws/service/canonical/ubuntu/*` for the AMI lookup, as well as S3 access to the state bucket.

To check if it works:
```bash
aws sts get-caller-identity --profile terraform-lab
```

### 2. Terraform state bucket

Since the terraform state will be stored on the AWS S3, you need to create your bucket first. Doing it manually via AWS console, or via command line doesn't matter.

### 3. Terraform variables

Create `terraform/terraform.tfvars` (gitignored):

```hcl
my_ip = "1.2.3.4/32"   # your public IP
ami_id = <ami_id>
instance_type = "t3.micro"
```
I personally hardcoded the AMI id after running:
```bash
aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id --region ap-southeast-3 --profile <your-profile>
```
You can also use any instance type you want, I use `t3.micro` mainly for cheaper cost.

### 4. Consul gossip encryption key

All Consul agents share one symmetric key. Generate it once:

```bash
consul keygen
```
or, if you don't have consul installed on your host, use this instead:
```bash
openssl rand -base64 32
```

Put it in `ansible/group_vars/all.yml`

---

## Run it

From the `service-discovery/` folder:

```bash
# 1. Provision the infrastructure
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# 2. Generate the Ansible inventory from Terraform outputs
./scripts/generate-inventory.sh

# 3. Check connectivity
ansible -i ansible/inventory.ini all -m ping --private-key ~/.ssh/<your-key>

# 4. Configure all servers
ansible-playbook -i ansible/inventory.ini ansible/main.yml \
  --private-key ~/.ssh/<your-key>
```

The playbook is idempotent. Re-run it after any template or variable change and only the changed tasks (and their handlers) will act.

---

## Verify

**Consul cluster membership** (on the Consul server):
```bash
ssh ubuntu@<consul-server-public-ip>
consul members
```
You should see four nodes, all `alive`.

**Consul UI:** open `http://<consul-server-public-ip>:8500`. This needs an ingress rule for port 8500 from your IP on the security group. Alternatively, use an SSH tunnel and open `http://localhost:8500`:
```bash
ssh -i ~/.ssh/<your-key> -L 8500:localhost:8500 ubuntu@<consul-server-public-ip>
```

**Load balancing:**
```bash
curl http://<load-balancer-public-ip>
```
Repeat a few times. The response should alternate between Backend 1 and Backend 2.

**Self-healing test:**
1. Open the `backend` service in the Consul UI.
2. SSH into one backend and run `sudo systemctl stop nginx`.
3. Within a few seconds its check turns red and the load balancer only returns the other backend.
4. Run `sudo systemctl start nginx` and it rejoins the rotation.

---

## Design notes

- **Terraform modules:** `vpc` and `ec2` live under `terraform/modules/`. The `ec2` module is called three times (Consul server, backends, load balancer) with different names and counts.
- **Single security group:** all four instances share `lab_sg`. Consul ports (8300-8600 TCP, 8301 UDP) are allowed with `self = true`, SSH only from `my_ip`, HTTP open on port 80.
- **No hardcoded IPs or secrets:** the Consul server's private IP comes from Terraform outputs through the generated inventory (`consul_server_private_ip`), and the encryption key comes from `group_vars`.
- **Per-host content:** each backend's `index.html` is rendered from a Jinja2 template using its inventory hostname, so no manual editing is needed.
- **Two template layers on the load balancer:** Ansible renders the `.ctmpl` file once with Jinja2, so it is wrapped in `{% raw %}` to keep the Go-template braces intact for consul-template.
- **Consul installed from apt:** the shared `consul_repo` role adds the HashiCorp repository, and the other roles depend on it through `meta/main.yml`.
- **Public subnet, no NAT:** keeping everything public avoids the NAT Gateway cost (about $32/month plus data charges), which would dwarf the instance cost for a short lab.

---

## Cost

Four `t3.micro` instances in Jakarta cost roughly $0.0132/hour each, so a few hours of testing is well under a dollar. The costs that can surprise you:

- Leaving the instances running for days
- An Elastic IP that is allocated but not attached to a running instance
- A NAT Gateway, if you add one (billed from creation, even if idle)

Auto-assigned public IPs change on a stop/start. Re-run `./scripts/generate-inventory.sh` after starting stopped instances.

---

## Clean up

```bash
terraform -chdir=terraform destroy
```

The S3 state bucket is not managed by this config. Delete it separately if you no longer need it.

---