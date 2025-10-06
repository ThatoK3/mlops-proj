# Use official Python runtime as base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies (if needed for your requirements)
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create directory structure
RUN mkdir -p /app/fast_api
RUN mkdir -p /app/models

# Copy application code (if not using volumes for development)
# COPY ./fast_api /app/fast_api/
# COPY ./models /app/models/

# Set the working directory to where main.py lives
WORKDIR /app/fast_api

# Expose port
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
