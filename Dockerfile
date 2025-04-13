# Set the Python version as a build-time argument (default: 3.12-slim-bullseye)
ARG PYTHON_VERSION=3.12-slim-bullseye
FROM python:${PYTHON_VERSION}

# Create a virtual environment
RUN python -m venv /opt/venv

# Set the virtual environment as the current location
ENV PATH=/opt/venv/bin:$PATH

# Upgrade pip
RUN pip install --upgrade pip

# Set Python-related environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install OS dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \ 
         # PostgreSQL dependencies
    libjpeg-dev \ 
       # Pillow dependencies
    libcairo2 \ 
         # CairoSVG dependencies
    gcc \
                # Other required dependencies
    && rm -rf /var/lib/apt/lists/*

# Create the project directory
RUN mkdir -p /code

# Set the working directory
WORKDIR /code

# Copy the requirements file into the container
COPY requirements.txt /tmp/requirements.txt

# Copy the project source code
COPY ./src /code

# Install the Python project dependencies
RUN pip install -r /tmp/requirements.txt

ARG DJANGO_SECRET_KEY= 
ENV DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}

ARG DJANGO_DEBUG=0
ENV DJANGO_DEBUG=${DJANGO_DEBUG}

RUN python manage.py vendor_pull
RUN python manage.py collectstatic --noinput
# Set the Django project name
ARG PROJ_NAME="B"

# Create a bash script to run the Django project
RUN printf "#!/bin/bash\n" > ./paracord_runner.sh && \
    printf "RUN_PORT=\"\${PORT:-8000}\"\n\n" >> ./paracord_runner.sh && \
    printf "python manage.py migrate --no-input\n" >> ./paracord_runner.sh && \
    printf "gunicorn ${PROJ_NAME}.wsgi:application --workers 4 --bind 0.0.0.0:\$RUN_PORT\n" >> ./paracord_runner.sh

# Make the script executable
RUN chmod +x ./paracord_runner.sh

# Clean up package manager cache
RUN apt-get remove --purge -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Run the Django project via the startup script when the container starts
CMD ["./paracord_runner.sh"]
