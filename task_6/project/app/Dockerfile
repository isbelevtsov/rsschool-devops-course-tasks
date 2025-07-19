FROM python:3.11-slim

# Install system updates and security patches
RUN apt-get update && apt-get upgrade -y && apt-get clean

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

# Create a non-root user and switch to it
RUN useradd --create-home appuser
USER appuser

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
