FROM python:3.10-slim

WORKDIR /app

COPY "Pyth Backend/Backend/requirements.txt" .

RUN pip install --upgrade pip && pip install -r requirements.txt

COPY "Pyth Backend/Backend" .

WORKDIR /app/backend

CMD python -m uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}