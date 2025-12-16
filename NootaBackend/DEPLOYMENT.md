# 🌐 Noota Backend Deployment Guide

Production deployment instructions for Google Cloud Run, AWS, or Heroku.

## Google Cloud Run (Recommended ⭐)

Best option: Manages serverless infrastructure, auto-scaling, GPU support available.

### Prerequisites

```bash
# Install Google Cloud CLI
# macOS:
brew install google-cloud-sdk

# Linux/Windows: https://cloud.google.com/sdk/docs/install

# Login to Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Deploy to Cloud Run

```bash
# From NootaBackend directory
cd NootaBackend

# Build and deploy
gcloud run deploy noota-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --set-env-vars FIREBASE_PROJECT_ID=your-project-id \
  --set-env-vars FIREBASE_PRIVATE_KEY='YOUR_PRIVATE_KEY' \
  --set-env-vars FIREBASE_CLIENT_EMAIL=your-email@project.iam.gserviceaccount.com \
  --set-env-vars FIREBASE_DATABASE_URL=https://your-project.firebaseio.com \
  --set-env-vars FIREBASE_STORAGE_BUCKET=your-project.appspot.com \
  --set-env-vars GOOGLE_CLOUD_API_KEY=YOUR_GOOGLE_CLOUD_API_KEY \
  --set-env-vars XTTS_SERVER_URL=https://xtts-backend-url.run.app \
  --set-env-vars NODE_ENV=production \
  --allow-unauthenticated
```

### Deploy XTTS Python Server

Since XTTS requires GPU and TensorFlow, you need a different approach:

**Option 1: Google Cloud Run with GPU** (Expensive but powerful)

```bash
# Create a Dockerfile for XTTS
cat > Dockerfile.xtts << 'EOF'
FROM nvidia/cuda:12.0-runtime-ubuntu22.04

WORKDIR /app

RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git

COPY requirements_xtts.txt .
RUN pip install --no-cache-dir -r requirements_xtts.txt

COPY xtts_server.py .

EXPOSE 8000

CMD ["python3", "xtts_server.py"]
EOF

# Build and deploy with GPU
gcloud run deploy noota-xtts \
  --source . \
  --dockerfile Dockerfile.xtts \
  --platform managed \
  --region us-central1 \
  --gpu 1 \
  --memory 8Gi \
  --cpu 4 \
  --timeout 300 \
  --allow-unauthenticated
```

**Option 2: Google Compute Engine (Recommended for XTTS)**

```bash
# Create VM instance with GPU
gcloud compute instances create noota-xtts \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --zone=us-central1-a

# SSH into instance
gcloud compute ssh noota-xtts --zone us-central1-a

# Then on the VM:
sudo apt-get update
sudo apt-get install -y python3.10 python3-pip
pip install -r requirements_xtts.txt
python xtts_server.py
```

**Option 3: Docker Hub + Self-hosted**

```bash
# Build Docker image
docker build -f Dockerfile.xtts -t your-dockerhub/noota-xtts:latest .

# Push to Docker Hub
docker push your-dockerhub/noota-xtts:latest

# Deploy on your own server:
docker run \
  -p 8000:8000 \
  --gpus all \
  your-dockerhub/noota-xtts:latest
```

## AWS Deployment

### Using AWS Lambda + API Gateway (Node.js Backend)

```bash
# Install AWS CLI
brew install awscli

# Configure credentials
aws configure

# Deploy with AWS SAM
sam build
sam deploy --guided
```

### Using EC2 for XTTS Server

```bash
# Launch EC2 instance with GPU (g4dn.xlarge or similar)
# Connect via SSH, then:

# Install Docker
curl https://get.docker.com | sh

# Build and run XTTS container
docker build -f Dockerfile.xtts -t noota-xtts .
docker run -d \
  -p 8000:8000 \
  --gpus all \
  noota-xtts
```

## Heroku Deployment (Simpler alternative)

⚠️ **Note**: Heroku doesn't support GPU, XTTS will be slow on CPU.

```bash
# Install Heroku CLI
brew install heroku

# Login
heroku login

# Create app
heroku create noota-backend

# Add environment variables
heroku config:set FIREBASE_PROJECT_ID=your-project-id
heroku config:set FIREBASE_PRIVATE_KEY='YOUR_KEY'
heroku config:set GOOGLE_CLOUD_API_KEY=YOUR_KEY

# Deploy
git push heroku main

# View logs
heroku logs --tail
```

## Docker Deployment

Create `Dockerfile` for Node.js Backend:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY src ./src

EXPOSE 8080

ENV PORT=8080

CMD ["node", "src/index.js"]
```

Build and deploy:

```bash
# Build
docker build -t noota-backend:latest .

# Run locally
docker run -p 5000:5000 \
  -e FIREBASE_PROJECT_ID=... \
  -e GOOGLE_CLOUD_API_KEY=... \
  noota-backend:latest

# Push to registry
docker tag noota-backend:latest your-registry/noota-backend:latest
docker push your-registry/noota-backend:latest
```

## Kubernetes Deployment

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: noota-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: noota-backend
  template:
    metadata:
      labels:
        app: noota-backend
    spec:
      containers:
      - name: backend
        image: your-registry/noota-backend:latest
        ports:
        - containerPort: 5000
        env:
        - name: FIREBASE_PROJECT_ID
          valueFrom:
            secretKeyRef:
              name: noota-secrets
              key: firebase-project-id
        - name: GOOGLE_CLOUD_API_KEY
          valueFrom:
            secretKeyRef:
              name: noota-secrets
              key: google-cloud-api-key
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: noota-backend-service
spec:
  selector:
    app: noota-backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  type: LoadBalancer
```

Deploy:

```bash
# Create secrets
kubectl create secret generic noota-secrets \
  --from-literal=firebase-project-id=YOUR_ID \
  --from-literal=google-cloud-api-key=YOUR_KEY

# Deploy
kubectl apply -f deployment.yaml

# Check status
kubectl get pods
kubectl logs -f deployment/noota-backend
```

## Monitoring & Logging

### Google Cloud Logging

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Create alert
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="Backend Error Rate High"
```

### AWS CloudWatch

```bash
# View logs
aws logs tail /aws/lambda/noota-backend --follow

# Create alarm
aws cloudwatch put-metric-alarm \
  --alarm-name noota-backend-errors \
  --metric-name Errors
```

## Performance Optimization

### For Node.js Backend

1. **Enable clustering** (multi-core)
   ```javascript
   import cluster from 'cluster';
   if (cluster.isMaster) {
     for (let i = 0; i < numCPUs; i++) {
       cluster.fork();
     }
   }
   ```

2. **Add caching** (Redis)
   ```bash
   npm install redis
   ```

3. **Load balancing** - Use Google Cloud Load Balancer or AWS ELB

### For XTTS Server

1. **Use GPU** - 4-5x faster than CPU
2. **Model quantization** - Reduce model size
3. **Request batching** - Process multiple requests in parallel
4. **Caching** - Cache generated audio

## Cost Estimation

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| Google Cloud Run (Backend) | $10-50 | Pay per request, includes free tier |
| Google Cloud Run (XTTS + GPU) | $200-500 | GPU adds cost |
| GCE (XTTS Server) | $150-300 | Tesla T4 GPU included |
| AWS Lambda + EC2 GPU | $200-400 | Flexible scaling |
| Heroku | $50-200 | Simple but no GPU support |
| Firebase Storage | $5-20 | Audio file storage |

## Health Checks

After deployment, verify:

```bash
# Backend health
curl https://your-backend-url.run.app/api/health

# XTTS health
curl https://your-xtts-url.run.app/health

# Full diagnostics
curl https://your-backend-url.run.app/api/health/detailed
```

## Troubleshooting Deployment

### Service fails to start
- Check logs: `gcloud logging read ...`
- Verify environment variables are set
- Check Firebase credentials format
- Ensure API keys are valid

### XTTS requests timeout
- XTTS on CPU is slow (30+ seconds)
- Deploy XTTS on GPU machine instead
- Increase Cloud Run timeout to 3600 seconds

### High costs
- Monitor Cloud Run invocations
- Reduce XTTS resolution if possible
- Use caching for repeated requests
- Consider batch processing

## Next Steps

1. Deploy Node.js Backend to Cloud Run
2. Deploy XTTS server (on GCE or EC2 with GPU)
3. Update iOS app with production URLs
4. Monitor logs and performance
5. Set up alerts for errors

For help, check service provider documentation:
- [Google Cloud Run](https://cloud.google.com/run/docs)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [Heroku](https://devcenter.heroku.com/)
