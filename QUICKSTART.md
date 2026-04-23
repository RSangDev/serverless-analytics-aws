# 🚀 Quick Start Guide

Get your Analytics API running in **5 minutes**!

## Prerequisites

✅ AWS Account (Free Tier)  
✅ AWS CLI installed  
✅ Python 3.11+

## Step-by-Step

### 1. Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

### 2. Clone & Deploy

```bash
# Clone repository
git clone <https://github.com/RSangDev/serverless-analytics-aws>
cd serverless-analytics-aws

# Deploy (one command!)
./scripts/deploy.sh

# Wait ~3 minutes for deployment...
```

### 3. Test API

```bash
# Run automated tests
./scripts/test-api.sh
```

### 4. Run Dashboard

```bash
# Install dependencies
cd dashboard
pip install -r requirements.txt

# Run Streamlit
streamlit run dashboard.py

# Opens at http://localhost:8501
```

### 5. Configure Dashboard

1. Copy API endpoint from deployment output
2. Paste in dashboard sidebar
3. Click "Save"
4. Start monitoring! 📊

## That's It! 🎉

Your serverless analytics platform is ready!

## What You Built

- ✅ REST API (API Gateway + Lambda)
- ✅ NoSQL Database (DynamoDB)
- ✅ Real-time Dashboard (Streamlit)
- ✅ Auto-scaling (Serverless)
- ✅ Monitoring (CloudWatch)
- ✅ **Total Cost: $0.00** 💰

## Next Steps

- Send events from your app
- Customize dashboard
- Add authentication
- Set up alerts

## Need Help?

- Check `README.md` for detailed docs
- Run `./scripts/test-api.sh` to verify setup
- View logs: `aws logs tail /aws/lambda/analytics-api-function --follow`

---

**Built with AWS Free Tier • Zero Cost • Infinite Possibilities** 🚀