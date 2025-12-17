FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements_docker_xtts.txt .

# Install Python packages (Kaggle-proven versions)
RUN pip install --no-cache-dir -r requirements_docker_xtts.txt

# Copy app code
COPY xtts_working_server.py .

# Expose port
EXPOSE 5000

# Run server
CMD ["python", "xtts_working_server.py"]
