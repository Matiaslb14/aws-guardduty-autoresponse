# 🛡️ AWS GuardDuty Auto-Response with WAF + Lambda + SNS

A serverless pipeline that implements automated incident response in AWS using **GuardDuty, EventBridge, Lambda, WAFv2 and SNS**.

## 🚀 What it does
- 🔍 GuardDuty detects malicious activity (e.g., suspicious connections, brute force).  
- ⏭️ EventBridge triggers a Lambda function.  
- 🐍 The Lambda function:
  - Extracts the attacker IP.  
  - Updates an AWS WAFv2 IPSet to block the IP.  
  - Sends an SNS notification (email alert).  
- ✅ Demonstrates a **SOAR-like workflow** (Security Orchestration, Automation and Response).  

## 📂 Repository structure

.
├── lambda/ # Lambda function (Python)
├── terraform/ # Terraform IaC for SNS, WAF, IAM, Lambda
│ ├── main.tf
│ ├── variables.tf
│ ├── outputs.tf
│ └── terraform.tfstate (ignored in VCS)
├── event-test.json # Sample event to test Lambda manually
└── README.md


## ⚙️ Prerequisites
- ☁️ AWS account with GuardDuty enabled.  
- 📦 Terraform installed (`>=1.5`).  
- 🔑 AWS CLI configured with a profile (Access Key + Secret).  
- 📧 Verified email address in Amazon SNS.  

## 🛠️ Getting started

## 1️⃣ Clone repository
```bash
git clone https://github.com/Matiaslb14/aws-guardduty-autoresponse.git
cd aws-guardduty-autoresponse/terraform

2️⃣ Initialize & validate

terraform init
terraform validate

3️⃣ Apply

terraform apply -auto-approve \
  -var alert_email="youremail@example.com" \
  -var aws_region="us-east-1" \
  -var aws_profile="your-aws-profile" \
  -var waf_scope="REGIONAL"

📩 Confirm the subscription email from AWS SNS.

🧪 Testing

🔹 Manual Test (without GuardDuty)

aws lambda invoke \
  --function-name gd-autoresponse-waf \
  --payload fileb://event-test.json \
  --region us-east-1 \
  /tmp/out.json && cat /tmp/out.json

Check:

✅ IP appears in the WAF IPSet.

✅ Alert received by SNS email.

✅ Logs in CloudWatch confirm execution.

🔹 With GuardDuty (once enabled)

DET=$(aws guardduty list-detectors --region us-east-1 --query 'DetectorIds[0]' --output text)
aws guardduty create-sample-findings --detector-id "$DET" --region us-east-1

🔮 Next steps

⏱️ Add DynamoDB TTL for temporary bans (auto-expire IPs after X hours).

🌐 Associate WAF Web ACL to ALB / API Gateway / CloudFront.

💬 Multi-channel notifications (Slack / Teams).

🧪 Add automated tests with pytest for Lambda.

📚 Skills demonstrated

🛡️ AWS Security: GuardDuty, WAFv2, SNS, Lambda

⚙️ Automation: Python + Terraform (IaC)

☁️ Cloud Security Engineering: detection → response → notification

🤖 SOAR mindset: automated incident response pipeline



