# Food Catalog Microservice

Dette projekt implementerer en microservice-løsning til et food catalog med brugergrænseflade og backend-services. Projektet indeholder en landing page, Razor-sider og API-endpoints, der integrerer med MongoDB via Docker Compose.

## Funktionalitet
- **Landing Page**: En HTML-baseret startside.
- **Catalog Service**: Et API til håndtering af produkter.
- **Razor Pages**: En brugergrænseflade til at liste produkter fra databasen.
- **MongoDB**: Databaseløsning til lagring af produktdata.
- **NGINX**: Load balancer og statisk filserver.

---

## Forudsætninger
- [Docker](https://www.docker.com/) installeret
- [Docker Compose](https://docs.docker.com/compose/) installeret
- [Postman](https://www.postman.com/) til test af API-endpoints (valgfrit)

---

## Installation

### 1. Clone repository

### 2. Log ind på Docker Hub
```bash
docker login
```
## Kør projektet med Docker Compose
 - Naviger til Staging-folderen:
 - Start miljøet:
```bash
docker-compose up -d
```

## Test API Endpoints
Brug Postman eller lignende værktøj til at teste følgende endpoints:

### 1. Få version af Catalog Service
**GET**:  
```http
http://localhost:4000/catalog/version
```
### 2. Opret et nyt produkt
**POST**:  
```http
http://localhost:4000/catalog/CreateProduct
```
**Body (JSON)**:
```json
{
  "productCategory": 1,
  "title": "Florida Green Tomatoes",
  "description": "Tomatoes from Florida.",
  "price": 2.75
}
```
### 3. Hent produkter efter kategori
**GET**:  
```http
http://localhost:4000/catalog/GetProductsByCategory?category=1
```

---

## Landing Page
Landing-pagen kan tilgås på:  
```http
http://localhost:4000/
```

