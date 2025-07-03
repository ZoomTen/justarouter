# Just A Router

## What

Exactly as it says on the tin:
```nim
import justarouter

type ServerState = object
  # this would be where parameters
  # you want to pass to the router would be,
  # if you had any.

makeRouter("routeThis", ServerState, string):
  get "/":
    output = "Welcome home!"
  
  get "/users/{id}/profile":
    let num = pathParams["id"].parseInt()
    if num == 10:
      output = "Name: avery"
    else:
      output = "Invalid user!"
  
  post "/upload":
    output = "hey!"
  
  default:
    output = "Not found..."
  
  methodNotAllowed:
    output = "Method not allowed"
  
  exceptionHandler:
    debugEcho "oops! " & e.repr
    output = "Something went wrong"

when isMainModule:
  let state = ServerState()
  var reply = ""

  # defined via makeRouter ^
  routeThis("GET", "/", state, reply)
  assert reply == "Welcome home!"
```

## Why

A lot of Nim web frameworks come bundled with an HTTP router.
For a project, I was using one that was quite barebones—not so much
a framework as it is a library. I didn't feel like ripping a router
from another framework, but I *was* inspired by the one that
Jester has.

## Implementation

1. Scan the AST of the `makeRouter` call
2. Separate out the static routes and dynamic routes
3. Create the "not found" and "method not allowed" templates within the new proc
4. Create a giant regex out of the collected dynamic routes
5. Use the giant regex to implement dynamic route processing.
6. Create a switch statement out of the collected static routes, and jumping into the dynamic route processing routine as a fallback.
7. Produce the final proc, wrapping it in an exception handler if one exists.

## Tips

- Since the regex works in order, you may want to put the most-used dynamic route earlier in the route definition order, that way those routes will run a little faster.
- The regex is generic, it can't be used to validate routes from the get-go.
