GET http://host.docker.internal:8080/health
HTTP 200
[Asserts]
jsonpath "$.status" == "UP"
