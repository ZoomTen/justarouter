import std/unittest
import ../justarouter

type ProbablyServerState = object

makeRouter("testRoute", ProbablyServerState, string):
  get "/":
    output = "get /"
  head "/":
    output = "head /"
  post "/":
    output = "post /"
  put "/":
    output = "put /"
  delete "/":
    output = "delete /"
  options "/":
    output = "options /"
  patch "/":
    output = "patch /"
  get "/crasher":
    let i = newStringTable({"abc": "123"})
    discard i["def"]
  get "/about":
    output = "get /about"
  get "/users/{id}/profile":
    output = "get profile of " & pathParams["id"]
  post "/users/{id}/profile":
    output = "post profile of " & pathParams["id"]
  get "/users/{id}/crasher":
    let i = newStringTable({"abc": "123"})
    discard i["def"]
  get "/users/{id}/image/{imageId}/{token}":
    output =
      "get params: [" & getParams & "], id: " & pathParams["id"] &
      ", image: " & pathParams["imageId"] & ", token: " &
      pathParams["token"]
  methodNotAllowed:
    output = "method not allowed"
  exceptionHandler:
    output = e.msg
  default:
    output = "not found"

suite "routing":
  var response = ""
  let state = ProbablyServerState()

  test "static routes":
    testRoute("GET", "/", state, response)
    check(response == "get /")

    testRoute("HEAD", "/", state, response)
    check(response == "head /")

    testRoute("POST", "/", state, response)
    check(response == "post /")

    testRoute("PUT", "/", state, response)
    check(response == "put /")

    testRoute("OPTIONS", "/", state, response)
    check(response == "options /")

    testRoute("PATCH", "/", state, response)
    check(response == "patch /")

    testRoute("DELETE", "/", state, response)
    check(response == "delete /")

  test "dynamic routes":
    testRoute("GET", "/users/149/profile", state, response)
    check(response == "get profile of 149")

    testRoute("POST", "/users/149/profile", state, response)
    check(response == "post profile of 149")

  test "not found response":
    testRoute("GET", "/abcdef", state, response)
    check(response == "not found")

    testRoute("GET", "/users/104/gallery", state, response)
    check(response == "not found")

  test "method not allowed response":
    testRoute("GET", "/about", state, response)
    check(response == "get /about")

    testRoute("POST", "/about", state, response)
    check(response == "method not allowed")

    testRoute("HEAD", "/users/100/profile", state, response)
    check(response == "method not allowed")

  test "exception handling":
    testRoute("GET", "/crasher", state, response)
    check(response == "key not found: def")

  test "dyn route with get params":
    testRoute(
      "GET", "/users/133/image/84752193/1acbde35", state,
      response,
    )
    check(
      response ==
        "get params: [], id: 133, image: 84752193, token: 1acbde35"
    )

    testRoute(
      "GET",
      "/users/133/image/9a9a9a9a/1acbde35?a=12&b=rjw&c=iAAAAAAAAAAAAAAAAAAAAA+",
      state, response,
    )
    check(
      response ==
        "get params: [a=12&b=rjw&c=iAAAAAAAAAAAAAAAAAAAAA+], id: 133, image: 9a9a9a9a, token: 1acbde35"
    )
  
  test "static route with trailing slash":
    testRoute("GET", "/about/", state, response)
    check(response == "get /about")
  
  test "dynamic route with missing parameter":
    testRoute("GET", "/users//profile", state, response)
    check(response == "not found")
  
  test "dynamic route with extra segment":
    testRoute("GET", "/users/149/profile/extra", state, response)
    check(response == "not found")
  
  test "method not allowed on dynamic route":
    testRoute("PUT", "/users/149/profile", state, response)
    check(response == "method not allowed")
  
  test "exception in dynamic route":
    testRoute("GET", "/users/149/crasher", state, response)
    check(response == "key not found: def")
  
  test "only GET params, no path":
    testRoute("GET", "?foo=bar", state, response)
    check(response == "not found")
  
  test "lowercase method is not accepted":
    testRoute("get", "/", state, response)
    check(response == "method not allowed")
  
  test "case sensitivity in path":
    testRoute("GET", "/About", state, response)
    check(response == "not found")

  test "dynamic route missing one param":
    testRoute("GET", "/users/133/image/84752193/", state, response)
    check(response == "not found")

  test "method not allowed on static route":
    testRoute("PATCH", "/about", state, response)
    check(response == "method not allowed")

  test "completely unknown path":
    testRoute("GET", "/this/does/not/exist", state, response)
    check(response == "not found")

  test "GET params with special characters":
    testRoute("GET", "/users/133/image/84752193/1acbde35?a=1%20b&b=%26", state, response)
    check(response.contains("a=1%20b&b=%26"))