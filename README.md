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
```bash
git clone https://github.com/<your-username>/FoodCatalogMicroservice.git
cd FoodCatalogMicroservice
```
### 2. Log ind på Docker Hub
```bash
docker login
```
## Kør projektet med Docker Compose
 - Naviger til Staging-folderen:
 - Start miljøet:
``` bash docker-compose up -d ```

## Landing page
http://localhost:4000/
