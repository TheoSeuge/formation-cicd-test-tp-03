GET http://host.docker.internal:8080/api/orders
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[0].id" == 1
jsonpath "$[0].product" == "Laptop"
jsonpath "$[0].price" == 1200.0
jsonpath "$[1].id" == 2
jsonpath "$[1].product" == "Mouse"
jsonpath "$[1].price" == 25.0
