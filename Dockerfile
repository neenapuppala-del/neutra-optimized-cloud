FROM python:3.10-slim

WORKDIR /app

COPY . .

WORKDIR /app/Pyth Backend/Backend

RUN pip install --upgrade pip && pip install -r requirements.txt

WORKDIR /app/Pyth Backend/Backend/backend

CMD python -m uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}