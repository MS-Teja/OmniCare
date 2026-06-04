# Use official Python runtime as a parent image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install Node.js (Required for npx mongodb-mcp-server) and clean up apt cache to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install the MongoDB MCP Server globally so npx runs instantly
RUN npm install -g mongodb-mcp-server@latest

# Copy the rest of the application
COPY . .

# Expose the port FastAPI runs on
EXPOSE 8080

# Command to run the application (Cloud Run uses PORT environment variable)
# Using 'exec' ensures uvicorn receives termination signals correctly
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
