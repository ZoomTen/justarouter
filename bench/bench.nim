import std/times
import ../justarouter

type RouterParams = object

# routes are very much order dependent
makeRouter("route", RouterParams, void):
  get "/":
    discard
  get "/{id}":
    discard
  get "/{id}/edit":
    discard
  post "/{id}/edit":
    discard
  get "/{id}/add":
    discard
  post "/{id}/add":
    discard
  get "/{id}/updates":
    discard
  post "/{id}/review":
    discard
  default:
    discard
  methodNotAllowed:
    discard

template run(which, params: untyped) =
  var s = cpuTime()
  for i in 0 .. 1_000_000:
    route("GET", which, params)
  echo "GET " & which, " --> ", (cpuTime() - s)
  s = cpuTime()
  for i in 0 .. 1_000_000:
    route("POST", which, params)
  echo "POST " & which, " --> ", (cpuTime() - s)
  s = cpuTime()
  for i in 0 .. 1_000_000:
    route("PATCH", which, params)
  echo "PATCH " & which, " --> ", (cpuTime() - s)
  s = cpuTime()
  for i in 0 .. 1_000_000:
    route("DELETE", which, params)
  echo "DELETE " & which, " --> ", (cpuTime() - s)

var params = RouterParams()
run("/", params)
run("/1235/edit", params)
run("/1235/edit/", params)
run("/1235/edit/?wfwe=25tt", params)
run("/1235", params)
run("/1235/updates", params)
run("/1235/updates/", params)
run("/1235/add", params)
run("/1235/add/", params)
run("/1235/review", params)
run("/1235/review/", params)
run("/ewffwe/", params)
run("/32032jc3/?wfwe=25tt", params)
