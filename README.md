# TP3 — Tests API et Sécurité dans une pipeline CI/CD

## Objectif du TP

Dans ce TP, vous allez mettre en place une pipeline CI/CD avec GitHub Actions qui permet de :
* démarrer une application Java simple,
* exécuter des tests API automatisés (tests fonctionnels),
* exécuter des tests de sécurité (tests non-fonctionnels),
* analyser les résultats directement depuis GitHub.

Aucun outil de test n’est à installer sur votre machine.
Tous les tests sont exécutés uniquement dans la pipeline CI/CD.

## Ce que vous allez apprendre

À la fin de ce TP, vous saurez :
* faire la différence entre tests unitaires, tests API et tests de sécurité,
* écrire des tests API simples et lisibles,
* comprendre comment une pipeline CI/CD orchestre plusieurs étapes de test,
* lire et interpréter des rapports de sécurité,
* comprendre pourquoi la pipeline est le juge final de la qualité.
  
## Types de tests couverts
### Tests fonctionnels — Tests API
* Vérifient le comportement de l’application via HTTP
* Testent les endpoints exposés
* Outil utilisé : Hurl
### Tests non-fonctionnels — Tests de sécurité
* Détectent des vulnérabilités connues
* Génèrent des rapports automatiques
* Outil utilisé : OWASP ZAP

## L’application du TP
Le projet contient une application Java simple (sans Spring Boot) qui expose une API HTTP sur le port 8080.

Endpoints disponibles
* GET /health => Retourne l’état de l’application
```json
{"status":"UP"}
```

* GET /api/orders => Retourne une liste de commandes
```json
[
  { "id": 1, "product": "Laptop", "price": 1200.0 },
  { "id": 2, "product": "Mouse",  "price": 25.0 }
]
```
*Prenez le temps de lire le code pour comprendre ce que fait chaque endpoint avant d’écrire les tests.*

## Structure du projet
```bash
formation-cicd-test-tp-03/
├── src/
│   ├── main/java/        # Code de l’application
│   └── test/java/api/    # Tests API (Hurl)
│       ├── health.hurl
│       └── orders.hurl
├── pom.xml
└── .github/workflows/ci.yml
```

## Commandes Maven importantes
Commandes Maven importantes
```bash
mvn clean package
```
Cette commande :
* compile le code,
* génère un jar exécutable dans target/,
* ne lance aucun test API.

Lancer l’application (pour compréhension uniquement)
```bash
java -jar target/formation-cicd-test-tp-03-1.0-SNAPSHOT.jar
```

## Fonctionnement global de la pipeline CI/CD
La pipeline est composée de deux jobs :
1. api-tests
2. security-scan
Le second job ne s’exécute que si le premier réussit.

## Job 1 — Tests API
### Étape 1 — Build de l’application
* Maven construit le projet
* Un jar exécutable est généré

```bash
run: mvn -q clean package
```

*Si le jar n’existe pas, la pipeline échoue.*

### Étape 2 — Démarrage de l’application
* L’application est lancée en arrière-plan
* Les logs sont enregistrés

```bash
nohup java -jar target/formation-cicd-test-tp-03-solution-1.0-SNAPSHOT.jar > ../app.log 2>&1 &
```

*En cas de problème, les logs sont affichés à la fin du job.*

### Étape 3 — Attente de disponibilité
* La pipeline interroge régulièrement /health
* Les tests ne démarrent que lorsque l’API est prête

```bash
      - name: Wait for API to be ready
        run: |
          for i in {1..30}; do
            if curl -sSf http://localhost:8080/health > /dev/null; then
              echo "API is up!"
              exit 0
            fi
            echo "Waiting API..."
            sleep 2
          done
          echo "API not ready"
          tail -n 200 app.log || true
          exit 1
```

### Étape 4 — Écriture des tests API

Les tests sont écrits dans des fichiers .hurl.

exemple src/test/java/api/health.hurl :
```hurl
GET http://host.docker.internal:8080/health
HTTP 200
[Asserts]
jsonpath "$.status" == "UP"
```

définissez le test src/test/java/api/orders.hurl pour tester le retour de l'API : /api/orders

Un test API doit :
* appeler un endpoint,
* vérifier le code HTTP,
* vérifier le contenu de la réponse.

### Étape 5 — Exécution des tests API
* Les tests sont exécutés via Hurl
* Hurl est lancé dans un conteneur Docker uniquement dans la CI
* Un test qui échoue → le job échoue

```bash
      - name: Run API tests (Hurl via Docker)
        run: |
          docker run --rm \
            --add-host=host.docker.internal:host-gateway \
            -v ${{ github.workspace }}:/work \
            ghcr.io/orange-opensource/hurl:latest \
            --test /work/src/test/java/api
```

### Étape 6 — Arrêt de l’application
* L’application est arrêtée proprement
* Cette étape s’exécute même en cas d’erreur

### Étape bonus — générer le rapport de test
* Ajouter les options reports à la commande run pour générer des rapports en json, html,...

```bash
            --report-junit /work/api-test-reports/junit.xml \
            --report-html /work/api-test-reports/report.html \
            --report-json /work/api-test-reports/report.json \ 
```
* Vous devez ajouter une étape avant pour créer le répertoire
* Ajouter une étape pour uploader les rapports dans un artefact.

```bash
      - name: Prepare API test reports directory
        run: mkdir -p api-test-reports 
```
* Analyse les rapports qui sont disponibles en tant qu’artifacts GitHub Actions.

## Job 2 — Tests de sécurité
### Étape 7 — Redémarrage de l’application
* On build à nouveau l’application
* on relance l’application le scan de sécurité
* on attend que l'API soit disponible 

*Les mémes étapes que le premier job. Vous savez pourquoi on refait les mémes étapes ?*

### Étape 8 — Scan OWASP ZAP
Il existe une action GitHub officielle permettant de lancer un scan OWASP ZAP facilement.
* Cette action permet :
  * de définir l’URL cible à analyser,
  * de choisir si le scan doit faire échouer la pipeline ou non,
  * de générer des rapports exploitables.
* Le scan doit être exécuté :
  * après les tests API,
  * uniquement si ces tests ont réussi.
* L’application doit être démarrée avant de lancer le scan.

Mots-clés utiles pour vos recherches :
* “GitHub Actions OWASP ZAP baseline”
* “zaproxy GitHub Action”
* “non-blocking security scan CI”

### Étape 9 — Conserver les résultats du scan de sécurité
* Le scan de sécurité ne sert à rien si ses résultats ne sont pas accessibles.
* Votre objectif est de rendre les rapports du scan consultables après l’exécution de la pipeline.

Indices : 
* Le scan de sécurité génère plusieurs fichiers de rapport (différents formats).
* Ces fichiers sont générés dans le workspace du runner CI.
* GitHub Actions propose une action standard permettant de :
  * conserver des fichiers après l’exécution d’un job,
  * les rendre téléchargeables depuis l’interface GitHub.
* Cette étape doit s’exécuter :
  * même si le scan détecte des problèmes,
  * donc indépendamment du succès ou de l’échec du job.

Mots-clés utiles pour vos recherches :
* “GitHub Actions upload artifact”
* “archive CI reports GitHub”
* “always() condition GitHub Actions”

### Étape 10 — Analyse des rapports
Les rapports sont disponibles en tant qu’artifacts GitHub Actipons.

Prenez le temps de :
* ouvrir le rapport HTML,
* identifier les types de vulnérabilités,
* comprendre leur niveau de gravité.