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

  # 1. Overlapping dynamic and static routes
  get "/users/static/profile":
    output = "static profile"
  get "/users/overlap/{id}":
    output = "dynamic overlap " & pathParams["id"]

  # 2. Dynamic route with adjacent braces
  get "/weird/{id}{token}":
    output =
      "adjacent: " & pathParams["id"] & "|" & pathParams[
        "token"
      ]

  # 3. Dynamic route with special characters in param
  get "/special/{id}/chars":
    output = "special: " & pathParams["id"]

  # 4. Empty path
  get "":
    output = "empty path"

  # 5. Root path with trailing slashes (handled by normalization)
  # Already covered by get "/"

  # 6. Multiple dynamic params with similar names
  get "/foo/{id}/bar/{id2}":
    output =
      "foo: " & pathParams["id"] & ", bar: " & pathParams["id2"]

  # 7. Dynamic route with optional segment (simulate)
  get "/maybe/{id}":
    output = "maybe: " & pathParams["id"]
  get "/maybe":
    output = "no id"

  # 8. Method not allowed for unusual methods (not defined, so handled by methodNotAllowed)

  # 9. GET params with duplicate keys (handled in test)

  # 10. Dynamic route with numeric and non-numeric IDs (handled in test)

  # 11. Exception in default handler
  default:
    raise newException(ValueError, "default fail")

  # 12. Dynamic route with URL-encoded braces (handled in test)

  # 13. Very long path (handled in test)

  # 14. GET param only, no path (handled in test)

  # 15. Dynamic route with duplicated param names
  get "/dup/{id}/dup/{id}":
    output = "dup: " & pathParams["id"]

  # 16. Route with dot or other special characters
  get "/file/{filename}.txt":
    output = "file: " & pathParams["filename"]

  # 17. Route with hyphens, underscores, and mixed case
  get "/hyphen-underscore_{id}":
    output = "hu: " & pathParams["id"]

  # 18. Route with query string but no path (handled in test)

  # 19. Route with only a slash (already covered)

  # 20. Route with Unicode characters
  get "/emoji/{icon}":
    output = "emoji: " & pathParams["icon"]

  methodNotAllowed:
    output = "method not allowed"
  exceptionHandler:
    output = e.msg

suite "Static routes":
  var response = ""
  let state = ProbablyServerState()

  test "GET /":
    testRoute("GET", "/", state, response)
    check(response == "get /")

  test "HEAD /":
    testRoute("HEAD", "/", state, response)
    check(response == "head /")

  test "POST /":
    testRoute("POST", "/", state, response)
    check(response == "post /")

  test "PUT /":
    testRoute("PUT", "/", state, response)
    check(response == "put /")

  test "OPTIONS /":
    testRoute("OPTIONS", "/", state, response)
    check(response == "options /")

  test "PATCH /":
    testRoute("PATCH", "/", state, response)
    check(response == "patch /")

  test "DELETE /":
    testRoute("DELETE", "/", state, response)
    check(response == "delete /")

  test "static route with trailing slash":
    testRoute("GET", "/about/", state, response)
    check(response == "get /about")

  test "case sensitivity in path (should not match)":
    testRoute("GET", "/About", state, response)
    check(response == "default fail")

suite "Dynamic routes":
  var response = ""
  let state = ProbablyServerState()

  test "GET dynamic route":
    testRoute("GET", "/users/149/profile", state, response)
    check(response == "get profile of 149")

  test "POST dynamic route":
    testRoute("POST", "/users/149/profile", state, response)
    check(response == "post profile of 149")

  test "dynamic route with missing parameter":
    testRoute("GET", "/users//profile", state, response)
    check(response == "default fail")

  test "dynamic route with extra segment":
    testRoute(
      "GET", "/users/149/profile/extra", state, response
    )
    check(response == "default fail")

  test "dynamic route missing one param (multiple params)":
    testRoute(
      "GET", "/users/133/image/84752193/", state, response
    )
    check(response == "default fail")

  test "dynamic route with trailing slash":
    testRoute("GET", "/users/149/profile/", state, response)
    check(response == "get profile of 149")

  test "dynamic route with get params":
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

  test "GET params with special characters":
    testRoute(
      "GET", "/users/133/image/84752193/1acbde35?a=1%20b&b=%26",
      state, response,
    )
    check(response.contains("a=1%20b&b=%26"))

suite "Method not allowed":
  var response = ""
  let state = ProbablyServerState()

  test "method not allowed on static route":
    testRoute("PATCH", "/about", state, response)
    check(response == "method not allowed")

  test "method not allowed on dynamic route":
    testRoute("PUT", "/users/149/profile", state, response)
    check(response == "method not allowed")

  test "method not allowed response (static)":
    testRoute("POST", "/about", state, response)
    check(response == "method not allowed")

  test "method not allowed response (dynamic)":
    testRoute("HEAD", "/users/100/profile", state, response)
    check(response == "method not allowed")

  test "lowercase method is not accepted (should not match)":
    testRoute("get", "/", state, response)
    check(response == "method not allowed")

suite "Not found/default handler":
  var response = ""
  let state = ProbablyServerState()

  test "not found response (static)":
    testRoute("GET", "/abcdef", state, response)
    check(response == "default fail")

  test "not found response (dynamic)":
    testRoute("GET", "/users/104/gallery", state, response)
    check(response == "default fail")

  test "completely unknown path":
    testRoute("GET", "/this/does/not/exist", state, response)
    check(response == "default fail")

  test "only GET params, no path":
    testRoute("GET", "?foo=bar", state, response)
    # pathOnly == ""
    check(response == "empty path")

suite "Exception handling":
  var response = ""
  let state = ProbablyServerState()

  test "exception in static route":
    testRoute("GET", "/crasher", state, response)
    check(response == "key not found: def")

  test "exception in dynamic route":
    testRoute("GET", "/users/149/crasher", state, response)
    check(response == "key not found: def")

# Test suites
suite "Weird and edge case routes":
  var response = ""
  let state = ProbablyServerState()

  # 1. Overlapping dynamic and static routes
  test "static route wins over dynamic":
    testRoute("GET", "/users/static/profile", state, response)
    check(response == "static profile")
  test "dynamic overlap route":
    testRoute("GET", "/users/overlap/xyz", state, response)
    check(response == "dynamic overlap xyz")

  # 2. Dynamic route with adjacent braces
  test "dynamic route with adjacent braces":
    testRoute("GET", "/weird/abc123def456", state, response)
    check(response.contains("adjacent:"))

  # 3. Dynamic route with special characters in param
  test "dynamic route with special chars (space)":
    testRoute("GET", "/special/a%20b/chars", state, response)
    check(response.contains("special:"))
  test "dynamic route with special chars (plus)":
    testRoute("GET", "/special/a+b/chars", state, response)
    check(response.contains("special:"))

  # 4. Empty path
  test "empty path route":
    testRoute("GET", "", state, response)
    check(response == "empty path")

  # 5. Root path with trailing slashes
  test "root path with one slash":
    testRoute("GET", "/", state, response)
    check(response == "get /")
  test "root path with two slashes":
    testRoute("GET", "//", state, response)
    # get /, since it's being read as "/"
    check(response == "get /")
  test "root path with three slashes":
    testRoute("GET", "///", state, response)
    # default fail, since it's being read as "//"
    # what should I do?
    check(response == "get /")

  # 6. Multiple dynamic params with similar names
  test "multiple dynamic params":
    testRoute("GET", "/foo/1/bar/2", state, response)
    check(response == "foo: 1, bar: 2")

  # 7. Dynamic route with optional segment (simulate)
  test "dynamic route with optional segment present":
    testRoute("GET", "/maybe/123", state, response)
    check(response == "maybe: 123")
  test "dynamic route with optional segment missing":
    testRoute("GET", "/maybe", state, response)
    check(response == "no id")

  # 8. Method not allowed for unusual method
  test "method not allowed for TRACE":
    testRoute("TRACE", "/", state, response)
    check(response == "method not allowed")

  # 9. GET params with duplicate keys
  test "GET params with duplicate keys":
    testRoute(
      "GET", "/users/1/profile?a=1&a=2", state, response
    )
    check(response.contains("get profile of 1"))

  # 10. Dynamic route with numeric and non-numeric IDs
  test "dynamic route with numeric id":
    testRoute("GET", "/users/123/profile", state, response)
    check(response == "get profile of 123")
  test "dynamic route with non-numeric id":
    testRoute("GET", "/users/abc/profile", state, response)
    check(response == "get profile of abc")

  # 11. Exception in default handler
  test "exception in default handler":
    testRoute("GET", "/notfound", state, response)
    check(response == "default fail")

  # 12. Dynamic route with URL-encoded braces
  test "dynamic route with url-encoded braces":
    testRoute("GET", "/users/%7Bid%7D/profile", state, response)
    check(response != "default fail")

  # 13. Very long path
  test "very long path":
    let longPath = "/" & "a/".repeat(100) & "end"
    testRoute("GET", longPath, state, response)
    check(response == "default fail")

  # 14. GET param only, no path
  test "GET param only, no path":
    testRoute("GET", "?foo=bar", state, response)
    check(response == "default fail")

  # 15. Dynamic route with duplicated param names
  test "dynamic route with duplicated param names":
    testRoute("GET", "/dup/1/dup/2", state, response)
    check(response == "dup: 2")

  # 16. Route with dot or other special characters
  test "route with dot and special chars":
    testRoute("GET", "/file/test.txt", state, response)
    check(response == "file: test")

  # 17. Route with hyphens, underscores, and mixed case
  test "route with hyphen and underscore":
    testRoute("GET", "/hyphen-underscore_foo", state, response)
    check(response == "hu: foo")

  # 18. Route with query string but no path
  test "route with query string but no path":
    testRoute("GET", "?a=1&b=2", state, response)
    check(response == "default fail")

  # 19. Route with only a slash (already covered above)

  # 20. Route with Unicode characters
  test "route with unicode emoji":
    testRoute("GET", "/emoji/😀", state, response)
    check(response == "emoji: 😀")
