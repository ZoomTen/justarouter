##[

Yep. it's Just An HTTP Router™.

It's a single macro that lets you define a proc that takes in
an uppercased HTTP method name, a URL (slash or no slash; doesn't matter),
a parameter object (server state, for example), and an optional output object.

Specifically, it will define this proc, where `T` and `U` are object types:
```nim
proc myRouterProc(reqType, path: string; params: T; output: var U): void
```

If `U` is `void`, however, then there will be no output variable:
```nim
proc myRouterProc(reqType, path: string; params: T): void
```

`myRouterProc` will be replaced with the name that you specified
in the `name` parameter of the `makeRouter`_ macro.

The `reqType` that this new proc will accept, are (**all uppercase**):

1. GET
2. HEAD
3. POST
4. PUT
5. DELETE
6. OPTIONS
7. PATCH

However, when defining a path for each of the methods, you
will define them using **lowercase** keywords. For example,
to define `GET /` and `PUT /obj`:

```nim
makeRouter("routeThis", ServerState, void):
  get "/":
    # statements...
    discard
  put "/obj":
    # other stuff...
    discard
  default:
    # not found
    discard
```

All routes must define the `default` route. This will fire when
a URL is not found or a method is not handled for the URL.

If you want to differentiate "unhandled method" with "not found",
you can define the `methodNotAllowed` path, although this is optional:

```nim
makeRouter("routeThis", ServerState, void):
  get "/":
    # statements...
    discard
  put "/obj":
    # other stuff...
    discard
  default:
    # not found
    discard
  methodNotAllowed:
    # not allowed
    discard
```

Exception handling is also possible, by specifying the
`exceptionHandler` route:

```nim
makeRouter("routeThis", ServerState, void):
  get "/":
    # statements...
    discard
  put "/obj":
    # other stuff...
    discard
  default:
    # not found
    discard
  methodNotAllowed:
    # not allowed
    discard
  exceptionHandler:
    # bam!
    debugEcho e.repr
    discard
```

Besides "static" routes like `/`, `/home`, `/about` etc., you can also
define "dynamic" routes that capture URL variables. The names of the
URL variables are enclosed in curly brackets and are made available
through a `StringTableRef` called `pathParams`:

```nim
makeRouter("test2"):
  get "/posts/{postId}":
    let id = pathParams.getOrDefault("postId")
    echo "got post ID: " & id
    # ...
```

On every route, the following variables are made available to you:
- `reqType`: From proc call.
- `path`: From proc call.
- `params`: From proc call.
- `output`: From proc call, if macro is invoked with a non-void output type.
- `pathOnly`: The URL part of the `path`.
- `pathParams`: Any variables captured in the dynamic route.
- `getParams`: The parameter part of the `path`.
- `e`: Captured expression -- **only on the `exceptionHandler` route!**

When you set `path` to `/test/abc?id=10&def=qwerty`:
- `pathOnly` = `/test/abc`
- `getParams` = `id=10&def=qwerty`



]##

runnableExamples:
  import std/strutils

  type MockDatabase = ref object

  type ServerState = ref object
    db: MockDatabase

  proc pretendExec(db: MockDatabase, query: string): string =
    case query
    of "SELECT name FROM user WHERE id = 10":
      return "avery"

  makeRouter("route", ServerState, string):
    get "/":
      output = "Welcome home!"
    get "/users/{id}/profile":
      let num = pathParams["id"].parseInt()
      if num == 10:
        let name = params.db.pretendExec("SELECT name FROM user WHERE id = 10")
        output = "Name: " & name
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
  
  let state = ServerState()
  var reply = ""

  route("GET", "/", state, reply)
  assert reply == "Welcome home!"

  route("GET", "/users/qwerty/profile", state, reply)
  assert reply == "Something went wrong"

  route("GET", "/users/12/profile", state, reply)
  assert reply == "Invalid user!"

  route("GET", "/users/10/profile", state, reply)
  assert reply == "Name: avery"

  route("POST", "/upload", state, reply)
  assert reply == "hey!"

  route("POST", "/", state, reply)
  assert reply == "Method not allowed"

  route("GET", "/jdoiwdjfoiergj", state, reply)
  assert reply == "Not found..."
      
      

import std/macros
import std/tables
import std/genasts

import std/strtabs
export strtabs

import std/strutils
export strutils

import regex
export regex

type RouterHttpMethods = enum
  Get = "GET"
  Head = "HEAD"
  Post = "POST"
  Put = "PUT"
  Delete = "DELETE"
  Options = "OPTIONS"
  Patch = "PATCH"

macro makeRouter*(
    name: string, paramType, outputType, body: untyped
) =
  when defined(routerMacroRuntimeDbg):
    debugEcho "===== WARNING: RUNTIME ECHO IS ENABLED ======"

  var staticRoutes:
    Table[string, seq[(RouterHttpMethods, NimNode)]]

  var dynamicRoutes:
    Table[string, seq[(RouterHttpMethods, NimNode)]]

  var defaultRoutine = newEmptyNode()
  var methodNotAllowedRoutine = newEmptyNode()
  var exceptionHandlerRoutine = newEmptyNode()

  #[
    Perform AST analysis
  ]#
  for node in body:
    case node.kind
    #[
    Statements of the form:
      get "/":
        <statements>
      post "/upload":
        <statements>
    ]#
    of nnkCommand:
      #[
        Normalize `get` into `GET`, etc. and ensure that it
        is a valid HTTP method name.
      ]#
      let methodName = parseEnum[RouterHttpMethods](
        node[0].strVal.toUpperAscii()
      )
      let methodBody = node[2]
      let routeEntry = (methodName, methodBody)
      #[
        Clean up the URL by truncating the trailing slash,
        unless it is "/", which indicates the root page.
      ]#
      let url = block:
        let originalUrl = node[1].strVal
        if len(originalUrl) > 1 and originalUrl[^1] == '/':
          let fixedUrl = originalUrl[0 ..^ 2]
          when defined(routerMacroDbg):
            debugEcho "===== router URL cleaned ========"
            debugEcho "was:  " & originalUrl
            debugEcho "into: " & fixedUrl
          fixedUrl
        else:
          originalUrl
      let isDynamicRoute = block:
        var determinant = false
        for i in url:
          if i == '{':
            determinant = true
            break
        determinant
      if isDynamicRoute:
        if not (url in dynamicRoutes):
          dynamicRoutes[url] = @[routeEntry]
        else:
          dynamicRoutes[url].add(routeEntry)
      else: # is static route
        if not (url in staticRoutes):
          staticRoutes[url] = @[routeEntry]
        else:
          staticRoutes[url].add(routeEntry)
    #[
      Statements of the form:
        default:
          <statements>
        methodNotAllowed:
          <statements>
        exceptionHandler:
          <statements>
    ]#
    of nnkCall:
      let methodName = node[0].strVal
      let methodBody = node[1]
      case methodName
      of "default":
        defaultRoutine = methodBody
      of "methodNotAllowed":
        methodNotAllowedRoutine = methodBody
      of "exceptionHandler":
        exceptionHandlerRoutine = methodBody
    else:
      discard

  when defined(routerMacroDbg):
    debugEcho "============= STATIC ROUTES ============="
    for k, v in pairs(staticRoutes):
      debugEcho k & ":"
      for m in v:
        let (mtd, node) = m
        debugEcho "  " & $mtd & " => " &
          node.repr.repr.replace("\n", "")
        debugEcho()
    debugEcho "============= DYNAMIC ROUTES ============="
    for k, v in pairs(dynamicRoutes):
      debugEcho k & ":"
      for m in v:
        let (mtd, node) = m
        debugEcho "  " & $mtd & " => " &
          node.repr.repr.replace("\n", "")
        debugEcho()

  #[
    Generate a regex pattern from all the dynamic routes
  ]#
  var genRegex = ""
  if len(dynamicRoutes) > 0:
    var counter = 0
    const paramConverter = re2"""\{(\w+)\}"""
    when defined(routerMacroDbg):
      debugEcho "============= DYNAMICROUTE NAMES ============"
    for url in keys(dynamicRoutes):
      #[
        Convert the captured URL into a regex... using regex!!

        URLs like `/user/{userId}/profile` will be converted into something like:
          /file/(?P<R1_userId>[^/]+?)/profile
        and used as a regex query.

        The "R1", "R2", ... names signify the route order, as in, in what order
        the scanner encountered this dynamic route. This is also useful for
        somewhat differentiating two routes with the same parameter name.

        The purpose of those names is that so the parameters can be easily
        captured by the route body.
      ]#
      when defined(routerMacroDbg):
        debugEcho "R" & $counter & " => " & url
      genRegex &= "(?P<R"
      genRegex &= $counter
      genRegex &= ">"
      genRegex &=
        url.replace(
          paramConverter,
          (
            proc(m: RegexMatch2, s: string): string =
              #[
                turn "{id}" into:
                  "(?P<R1_id>[^/]+?)"
                  "(?P<R2_id>[^/]+?)"
                  etc.
              ]#
              "(?P<R" & $counter & "_" & s[m.group(0)] &
                ">[^/]+?)"
          ),
        )
      #[
        Add an OR symbol after each route
      ]#
      genRegex &= "$)|"
      inc(counter)
    #[
      Cut the final OR symbol
    ]#
    genRegex = genRegex[0 ..< (len(genRegex) - 1)]

    when defined(routerMacroDbg):
      debugEcho "============= GENERATED REGEX PATTERN ============="
      debugEcho genRegex

  #[
    Generate handler proc that runs when the URL is not in any of the
    defined routes.

    reqType = "GET", "POST", etc.
    pathOnly = "/id/10/profile"
    getParams = "?action=edit"
    pathParams = {"userId": "10"}
    params = <user defined>
    output = <user defined>, is omitted when its type is `void`
  ]#
  var defaultProc = block:
    if outputType.strval == "void":
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
        paramType = paramType,
        d = defaultRoutine,
      ):
        template notFound(
            reqType, pathOnly, getParams: string,
            pathParams: StringTableRef,
            params: paramType,
        ): void =
          d

    else:
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
        output = ident("output"),
        paramType = paramType,
        outputType = outputType,
        d = defaultRoutine,
      ):
        template notFound(
            reqType, pathOnly, getParams: string,
            pathParams: StringTableRef,
            params: paramType,
            output: var outputType,
        ): void =
          d

  let defaultProcCall = block:
    if outputType.strval == "void":
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
      ):
        notFound(
          reqType, pathOnly, getParams, pathParams, params
        )
    else:
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
        output = ident("output"),
      ):
        notFound(
          reqType, pathOnly, getParams, pathParams, params,
          output,
        )

  #[
    Generate "method not allowed" proc, if specified. Arguments
    are the same as above.
  ]#
  var methodNotAllowedProc = block:
    if methodNotAllowedRoutine.kind == nnkEmpty:
      newEmptyNode()
    else:
      if outputType.strval == "void":
        genAst(
          reqType = ident("reqType"),
          pathOnly = ident("pathOnly"),
          getParams = ident("getParams"),
          pathParams = ident("pathParams"),
          params = ident("params"),
          paramType = paramType,
          d = methodNotAllowedRoutine,
        ):
          template methodNotAllowed(
              reqType, pathOnly, getParams: string,
              pathParams: StringTableRef,
              params: paramType,
          ): void =
            d

      else:
        genAst(
          reqType = ident("reqType"),
          pathOnly = ident("pathOnly"),
          getParams = ident("getParams"),
          pathParams = ident("pathParams"),
          params = ident("params"),
          paramType = paramType,
          output = ident("output"),
          outputType = outputType,
          d = methodNotAllowedRoutine,
        ):
          template methodNotAllowed(
              reqType, pathOnly, getParams: string,
              pathParams: StringTableRef,
              params: paramType,
              output: var outputType,
          ): void =
            d

  let methodNotAllowedCall = block:
    if outputType.strval == "void":
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
      ):
        methodNotAllowed(
          reqType, pathOnly, getParams, pathParams, params
        )
    else:
      genAst(
        reqType = ident("reqType"),
        pathOnly = ident("pathOnly"),
        getParams = ident("getParams"),
        pathParams = ident("pathParams"),
        params = ident("params"),
        output = ident("output"),
      ):
        methodNotAllowed(
          reqType, pathOnly, getParams, pathParams, params,
          output,
        )

  #[
    Build switch statement for static routes, which looks like:

    case pathOnly
    of "/":
      case reqType
      of "GET":
        <statements>
    of "/about":
      case reqType
      of "GET":
        <statements>
      of "POST":
        <statements>
  ]#
  var routeSwitch = nnkCaseStmt.newTree(ident("pathOnly"))
  for routeName, routeBody in pairs(staticRoutes):
    var rqSwitch = nnkCaseStmt.newTree(ident("reqType"))
    for i in routeBody:
      let (rqKind, rqRoutine) = i
      rqSwitch.add(
        nnkOfBranch.newTree(newStrLitNode($rqKind), rqRoutine)
      )
    rqSwitch.add(
      nnkElse.newTree(
        if methodNotAllowedRoutine.kind != nnkEmpty:
          methodNotAllowedCall
        else:
          defaultProcCall
      )
    )
    routeSwitch.add(
      nnkOfBranch.newTree(
        newStrLitNode(routeName), newStmtList(rqSwitch)
      )
    )

  #[
    And then build the less trivial dynamic routing, which is
    just an if-else if-else if loop.
  ]#
  var dynamicRouteRoutine =
    newStmtList(newCommentStmtNode("dynamic path fallback"))
  if len(genRegex) > 0:
    #[
      Common variables
    ]#
    let matchedRouteHolderName = genSym(nskVar, "matchedRoute")

    #[
      Case statement
    ]#
    let matchFoundCaseStmts =
      nnkCaseStmt.newTree(matchedRouteHolderName)

    var counter = 0

    for k, v in pairs(dynamicRoutes):
      #[
        Reserve a branch for the found route
      ]#
      var matchFoundMtdCases = newStmtList()
      matchFoundCaseStmts.add:
        nnkOfBranch.newTree(
          newLit("R" & $counter), matchFoundMtdCases
        )

      when defined(routerMacroRuntimeDbg):
        matchFoundMtdCases.add:
          genAst(
            which = newLit("R" & $counter),
            getParams = ident("getParams"),
            pathParams = ident("pathParams"),
          ):
            debugEcho("=== CURRENT ROUTE => ", which)
            debugEcho("=== PATH PARAMS => ", pathParams)
            debugEcho("=== GET PARAMS => ", getParams)

      #[
        Define a switch statement for the type of request
      ]#
      matchFoundMtdCases.add:
        nnkCaseStmt.newTree(ident("reqType"))
      #[
        Add a branch for each method of the endpoint
      ]#
      for endpoint in v:
        let (reqMethod, content) = endpoint
        matchFoundMtdCases[^1].add:
          nnkOfBranch.newTree(newLit($reqMethod), content)
      #[
        Add a final branch for "method not allowed"
      ]#
      matchFoundMtdCases[^1].add:
        nnkElse.newTree(
          newStmtList(
            newCommentStmtNode("invalid method"),
            (
              if methodNotAllowedRoutine.kind != nnkEmpty:
                methodNotAllowedCall
              else:
                defaultProcCall
            ),
          )
        )
      inc(counter)

    #[
      No dynamic route was matched, for whatever reason.
    ]#
    matchFoundCaseStmts.add:
      nnkElse.newTree(
        newStmtList(
          newCommentStmtNode("something went wrong"),
          defaultProcCall,
        )
      )

    #[
      Combine all of the generated regexes to find a route that can
      be matched for some URL
    ]#
    let giantRegex =
      nnkCallStrLit.newTree(ident("re2"), newLit(genRegex))

    dynamicRouteRoutine.add:
      genAst(
        pathOnly = ident("pathOnly"),
        pathParams = ident("pathParams"),
        matchedRouteHolderName = matchedRouteHolderName,
        giantRegex = giantRegex,
        dynRouteLen = len(dynamicRoutes),
        caseStmts = matchFoundCaseStmts,
        defaultProcCall = defaultProcCall,
      ):
        const rexp = giantRegex
        var m: RegexMatch2
        ##[
          Match against the overall regex
        ]##
        if match(pathOnly, rexp, m):
          let groupNames = groupNames(m)
          var matchedRouteHolderName = ""
          ##[
            Find the first route that matches the URL
          ]##
          for i in 0 ..< dynRouteLen:
            let routeNameCandidate = "R" & $i
            try:
              if m.group(routeNameCandidate) != reNonCapture:
                matchedRouteHolderName = routeNameCandidate
                break
            except KeyError:
              ##[
                Exit here, since there is no route that matches
              ]##
              defaultProcCall
              return
          ##[
            Insert the captured path parameters
          ]##
          if len(matchedRouteHolderName) > 1:
            for i in groupNames:
              if (
                i.startsWith(matchedRouteHolderName) and
                len(i) > len(matchedRouteHolderName)
              ):
                try:
                  pathParams[
                    i[(len(matchedRouteHolderName) + 1) ..^ 1]
                  ] = pathOnly[m.group(i)]
                  discard
                except KeyError:
                  ##[
                    Should we ignore non-matching?
                  ]##
                  discard
            caseStmts
          else:
            ##[
              Nothing REALLY matched
            ]##
            defaultProcCall
        else:
          ##[
            Nothing matched
          ]##
          defaultProcCall
  else:
    #[
      If there are no dynamic routes detected, this is just
      a call to the "not found" proc.
    ]#
    dynamicRouteRoutine.add(defaultProcCall)

  #[
    Append this monster of a dynamic route handler as the
    `else` branch of the static route switch
  ]#
  routeSwitch.add(nnkElse.newTree(dynamicRouteRoutine))

  #[
    Build the part where the path gets split into
    `pathOnly` and `getParams`
  ]#
  let splitPath = block:
    genAst(
      path = ident("path"),
      pathOnly = ident("pathOnly"),
      getParams = ident("getParams"),
    ):
      ##[
        Calculate where the path should split
      ]##
      var startPos = -1
      for i in 0 ..< len(path):
        case path[i]
        of '?', '&':
          startPos = i
          break
        else:
          discard
      ##[
        Accessible path
      ]##
      let pathOnly = block:
        var p =
          if startPos > -1:
            path[0 ..< startPos]
          else:
            path
        ##[
          Clean up trailing slash
        ]##
        if len(p) > 1 and p[^1] == '/':
          p[0 ..^ 2]
        else:
          p
      ##[
        Raw GET params
      ]##
      let getParams = block:
        if startPos > -1:
          path[(startPos + 1) ..^ 1]
        else:
          ""

  #[
    Statement to reserve a `pathParams` variable
  ]#
  let pathParamsDefine = nnkVarSection.newTree(
    nnkIdentDefs.newTree(
      ident("pathParams"),
      newEmptyNode(),
      newCall(ident("newStringTable")),
    )
  )

  #[
    Build the final router proc...
  ]#
  let routerBodyInner = newStmtList(
    defaultProc, #[ "Not found" proc define ]#
    methodNotAllowedProc, #[ "Not allowed" proc define ]#
    pathParamsDefine, #[ `pathParams` define ]#
    splitPath, #[ Split path into `pathOnly` and `getParams` ]#
    routeSwitch, #[ Perform routing ]#
  )

  let routerBody =
    if exceptionHandlerRoutine.kind != nnkEmpty:
      #[ Wrap the router body if an exception handler is set ]#
      genAst(
        routerBodyInner = routerBodyInner,
        exceptionHandlerRoutine = exceptionHandlerRoutine,
        e = ident("e"),
      ):
        try:
          routerBodyInner
        except Exception as e:
          exceptionHandlerRoutine
    else:
      routerBodyInner

  #[
    And then wrap this final proc into something we can actually call.
  ]#
  let builtProc = block:
    if outputType.strval == "void":
      genAst(
        routerName = ident(name.strVal),
        reqType = ident("reqType"),
        path = ident("path"),
        params = ident("params"),
        paramType = paramType,
        routerBody = routerBody,
      ):
        proc routerName(
            reqType, path: string, params: paramType
        ): void =
          routerBody

    else:
      genAst(
        routerName = ident(name.strVal),
        reqType = ident("reqType"),
        path = ident("path"),
        params = ident("params"),
        output = ident("output"),
        paramType = paramType,
        outputType = outputType,
        routerBody = routerBody,
      ):
        proc routerName(
            reqType, path: string,
            params: paramType,
            output: var outputType,
        ): void =
          routerBody

  when defined(routerMacroDbg):
    debugEcho "======BUILT========="
    debugEcho builtProc.repr

  #[
    At last, we now have our generated proc.
  ]#
  builtProc
