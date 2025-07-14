##[

Yep. it's Just An HTTP Router™.

It's a single macro that lets you define a proc that takes in:

1. an uppercased HTTP method name
2. a URL (slash or no slash; doesn't matter)
3. a parameter object (server state, for example), and
4. an optional output object.

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

## Defining endpoints

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

All routes **must** define the `default` route. This will fire when
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
`exceptionHandler` route (the exception object will be captured as `e` in its scope):

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

### Dynamic routes

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

### Variables injected at endpoint code

On every route, the following variables are made available to you:
- `reqType`: From proc call.
- `path`: From proc call.
- `params`: From proc call.
- `output`: From proc call, if macro is invoked with a non-void output type.
- `pathOnly`: The URL part of the `path`.
- `pathParams`: Any variables captured in the dynamic route.
- `getParams`: The parameter part of the `path`.
- `e`: Captured exception -- **only on the `exceptionHandler` route!**

When you set `path` to `/test/abc?id=10&def=qwerty`:
- `pathOnly` = `/test/abc`
- `getParams` = `id=10&def=qwerty`

## Generating OpenAPI specs

Using the `routerGenerateSwagger` define, you can automatically
generate OpenAPI spec (.json) files at compile time. They will
be stored as `router_ROUTERNAME.json` in your **current working directory**,
where ROUTERNAME is the name of the router defined when calling
this macro.

This, however, will not work when you run `nim check`, only upon
`nim run` or `nim compile`. You can define
`routerGenerateSwaggerStdout` *also*, to output the json to the
terminal.

```nim
makeRouter("routeThis", Something, string):
  ## @version 1.0
  ## @title My API
  ## @description Something
  ## @server http://127.0.0.1/api
  ## @server http://example.com/api Production server
  ## @schema OkResponse { "type": "object" }
  ## @security ApiKeyAuth { "type": "apiKey", "in": "header", "name": "X-API-Key" }
  ## @security OAuth2 { "type": "oauth2", "flows": {} }

  get "/":
    ## @description Root page, something something something.
    ## @summary Root page
    ## @tag Main
    ## @parameter roomId (path): integer required "Something something something"
    ## @produces application/json
    ## @security ApiKeyAuth []
    ## @security OAuth2 ["read", "write"]
    ## @response 200 (OkResponse) "Request completed"
    ## @response 400
    ## @response 404
    output = "get /"
```

Information can be defined line-by-line, with each line starting with
an @, followed by the tag, then the arguments. Lines not starting with
an @ will be ignored, and can be used for general comments (which
will not show up in the generated specs).

### General API information

These tags are defined as the docstring of the macro invocation itself. Unless otherwise specified, arguments may have spaces.

```
@version <Version number>
```
- Maps directly to key `.info.version`.

```
@title <API title>
```
- Maps directly to key `.info.title`.

```
@description <API description>
```
- Maps directly to key `.info.description`.

```
@server <Base URL>
@server <Base URL> <Server description>
```
- Maps to key `.servers`.
- Multiple of these can be specified, in any form.
- Server description is optional.
- Base URL may NOT have spaces (but `%20`, if your URL has them)

```
@schema <Object name> <OpenAPI schema definition>
```
- Maps to `.components.schemas`.
- Multiple can be specified.
- OpenAPI schema definition must be a valid JSON.
- Object name may NOT have spaces. 

I wanted to map it to Nim's objects but I couldn't find out how to capture things that are nearby the *invocation* of the macro. Instead it grabs things near the macro implementation itself... so rather than contort myself, I made it just take the OpenAPI json instead. :(

```
@security <Security scheme name> <OpenAPI security scheme definition>
```
- Maps to `.components.securitySchemes`.
- Multiple can be specified.
- Security scheme name may NOT have spaces.

### Route information

These tags are defined underneath the endpoint definition (i.e. `get "/":`) also as docstrings. Again, unless otherwise specified, arguments may have spaces.

```
@description <Description>
```
- Maps to `.paths.*.*.description`.

```
@summary <summary>
```
- Maps to `.paths.*.*.summary`.

```
@tag <Tag>
```
- Maps to `.paths.*.*.tags`.
- Multiple of these can be specified.

```
@parameter <Param name> (<Location>): <Type> required "<Description>"
@parameter <Param name> (<Location>): <Type> "<Description>"
@parameter <Param name> (<Location>): "<Description>"
```
- Maps to `.paths.*.*.parameters`.
- Multiple of these can be specified, in any form.
- Param name, Location, and Type may NOT have spaces.
- Location means "path", "body", etc. (What the OpenAPI specs support)
- Type can either be a primitive type (integer, string, etc.), or something that is defined as a `@schema` in the General API information.
- If there is a `@schema` with the name of `integer`, then that will take priority. Not sure what you need this info for, but thought I'd let you know of this parse quirk.
- If the Type is left out, then the parameter will be implicitly taken as a `string`.
- Yes, the spacing arrangement is exactly like that.
- Yes, `required` is lower-case.

```
@body <Type> required "<Description>"
@body <Type> "<Description>"
@body "<Description>" 
```
- Maps to `.paths.*.*.requestBody`.
- Type may NOT have spaces.
- Type can either be a primitive type (integer, string, etc.), or something that is defined as a `@schema` in the General API information.
- If there is a `@schema` with the name of `integer`, then that will take priority.
- If the Type is left out, then the parameter will be implicitly taken as a `string`.
- There can only be one of these, any @body definition after the first one will be ignored.
- Yes, `required` is lower-case.

```
@produces <MIME type>
```
- Maps to `.paths.*.*.content.<MIME type>`.
- It's named after the `produces` section of Swagger 2.x.
- There can only be one of these, only the last @produces definition will be used.

.. tip::
  - If it returns JSON, put in `application/json`.
  - If it returns an HTML document or a fragment, put in `text/html`.

```
@consumes <MIME type>
```
- Maps to `.paths.*.*.requestBody.content.<MIME type>`.
- It's named after the `consumes` section of Swagger 2.x.
- There can only be one of these, only the last @consumes definition will be used.

.. tip::
  - If it's an HTML form, put in `application/x-www-form-urlencoded`.
  - If it's an HTML form containing files, put in `multipart/form-data`.

```
@response <HTTP code>
@response <HTTP code> "<Description>"
@response <HTTP code> (<Type>)
@response <HTTP code> (<Type>) "<Description>"
```
- Maps to `.paths.*.*.responses`.
- Multiple of these can be specified, in any form.
- HTTP code and schema may NOT have spaces.
- Type can either be a primitive type (integer, string, etc.), or something that is defined as a `@schema` in the General API information.
- Type follows the same rules as `@parameter`.

```
@security <Security scheme name> <JSON array>
```
- Maps to `.paths.*.*.security`.
- Security scheme name may NOT have spaces.
- Security scheme name MUST be something that is defined as `@security` in the General API information.

## Available defines

### routerGenerateSwagger

See section "Generating OpenAPI specs".

### routerGenerateSwaggerStdout

See section "Generating OpenAPI specs". This define should appear **in addition to** `routerGenerateSwagger`.

### routerMacroDbg

This define will list static routes, dynamic routes, and the proc it ends
up generating, for each time this macro is invoked.

### routerMacroRuntimeDbg

This define will inject `debugEcho` statements each time a dynamic
route is accessed. It will output:

- which route was accessed
- what path params did get parsed
- the extracted GET params

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
        let name = params.db.pretendExec(
          "SELECT name FROM user WHERE id = 10"
        )
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
import std/httpcore

import std/strtabs
export strtabs

import std/strutils
export strutils

import regex
export regex

when defined(routerGenerateSwagger):
  import std/json
  import std/options

type RouterHttpMethods = enum
  Get = "GET"
  Head = "HEAD"
  Post = "POST"
  Put = "PUT"
  Delete = "DELETE"
  Options = "OPTIONS"
  Patch = "PATCH"

when defined(routerGenerateSwagger):
  proc parseSwaggerDocComment(
      doc: string
  ): Option[Table[string, seq[string]]] =
    var s = doc.strip()
    if (len(s) < 1) or (len(s) > 0 and s[0] != '@'):
      return none(Table[string, seq[string]])
    var k = initTable[string, seq[string]]()
    for line in splitLines(s):
      var i = line.strip()
      if (len(i) < 1) or (len(i) > 0 and i[0] != '@'):
        continue
      var paramArgs = i.split(' ', maxsplit = 1)
      if len(paramArgs) < 2:
        continue
      let paramName = paramArgs[0][1 ..^ 1].toLowerAscii()
      if not k.hasKey(paramName):
        k[paramName] = newSeq[string]()
      k[paramName].add(paramArgs[1])
    return some(k)

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

  when defined(routerGenerateSwagger):
    var api =
      %*{
        "openapi": "3.0.0",
        "info": {},
        "servers": [],
        "paths": {},
        "components": {"securitySchemes": {}, "schemas": {}},
      }
    var schemaDefs: seq[string] = @[]

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
      when defined(routerGenerateSwagger):
        if (
          len(methodBody) > 0 and
          methodBody[0].kind == nnkCommentStmt
        ):
          let parsedDocResult =
            methodBody[0].strVal.parseSwaggerDocComment()
          if parsedDocResult.isSome():
            let parsedDoc = parsedDocResult.get()
            if not api["paths"].hasKey(url):
              api["paths"][url] = %*{}
            let mtdNameLower = ($methodName).toLowerAscii()
            api["paths"][url][mtdNameLower] = %*{}
            var produceType = ""
            var consumeType = ""
            for k, v in pairs(parsedDoc):
              case k
              of "tag":
                if not api["paths"][url][mtdNameLower].hasKey(
                  "tags"
                ):
                  api["paths"][url][mtdNameLower]["tags"] = %*[]
                for tagDef in v:
                  api["paths"][url][mtdNameLower]["tags"].add(
                    tagDef.newJString()
                  )
              of "produces":
                for prodDef in v:
                  produceType = prodDef
              of "consumes":
                for consDef in v:
                  consumeType = consDef
              of "security":
                if not api["paths"][url][mtdNameLower].hasKey(
                  "security"
                ):
                  api["paths"][url][mtdNameLower]["security"] =
                    %*[]
                for securityDef in v:
                  let n = securityDef.split(' ', maxsplit = 1)
                  let securityDefName = n[0]
                  let securityDefContent = n[1].parseJson()
                  api["paths"][url][mtdNameLower]["security"].add(
                    %*{securityDefName: securityDefContent}
                  )
              of "parameter":
                if not api["paths"][url][mtdNameLower].hasKey(
                  "parameters"
                ):
                  api["paths"][url][mtdNameLower]["parameters"] =
                    %*[]
                for paramDef in v:
                  #[
                  Accepts the following:
                  - paramName (location): type required "description"
                  - paramName (location): type "description"
                  - paramName (location): "description"
                  
                  For the last one, the type is implicitly taken to be a string.
                  The type is something that is either a basic JSON type or
                  something referenced in the route @schema types, where the
                  latter takes preference.
                  ]#
                  var m = RegexMatch2()
                  let txt = paramDef
                  if regex.match(
                    txt,
                    re2"""(?x)
                    ^
                      (?P<paramName>\w+)
                      \s+
                      \( (?P<location>\w+) \)
                      : \s+
                      (?:
                        (?P<type>\w+)
                        (?:\s+(?P<requiredFlag>required))?
                        \s+
                      )?
                      "(?P<description>.+?)"
                    $""",
                    m,
                  ):
                    var newParam =
                      %*{
                        "name": txt[m.group("paramName")],
                        "in": txt[m.group("location")],
                        "description":
                          txt[m.group("description")],
                      }
                    newParam["required"] = (
                      m.group("requiredFlag").a > -1
                    ).newJBool()
                    newParam["schema"] = block:
                      let typeName =
                        if m.group("type").a > -1:
                          txt[m.group("type")]
                        else:
                          "string"
                      if typeName in schemaDefs:
                        %*{
                          "$ref":
                            "#/components/schemas/" & typeName
                        }
                      else:
                        %*{"type": typeName}

                    api["paths"][url][mtdNameLower][
                      "parameters"
                    ].add(newParam)
              of "body":
                if not api["paths"][url][mtdNameLower].hasKey(
                  "requestBody"
                ):
                  api["paths"][url][mtdNameLower]["requestBody"] = %*{"content": {consumeType: {}}}
                for bodyDef in v:
                  #[
                  Accepts the following:
                  - TypeName required "description"
                  - TypeName "description"
                  - "description"

                  TypeName should be something that is defined
                  in the @schema of the containing router.
                  ]#
                  var m = RegexMatch2()
                  let txt = bodyDef
                  var description = ""
                  if regex.match(
                    txt,
                    re2"""(?x)
                    ^
                      (?:
                        (?P<bodyType>\w+)
                        \s+

                        (?:
                          (?P<requiredFlag>required)
                          \s+
                        )?
                      )?
                      "
                      (?P<bodyDescription>.+?)
                      "
                    $
                    """,
                    m
                  ):
                    block insertDescription:
                      let i = m.group("bodyDescription")
                      if i.a < 0:
                        break insertDescription
                      api["paths"][url][mtdNameLower]["requestBody"]["description"] = txt[i].newJString()
                    block determineRequired:
                      let i = m.group("requiredFlag")
                      if i.a < 0:
                        break determineRequired
                      api["paths"][url][mtdNameLower]["requestBody"]["required"] = true.newJBool()
                    block determineBodyType:
                      let i = m.group("bodyType")
                      if i.a < 0:
                        break determineBodyType
                      else:
                        let typeName = txt[i]
                        api["paths"][url][mtdNameLower]["requestBody"]["content"][consumeType]["schema"] = if typeName in schemaDefs:
                            %*{
                              "$ref":
                                "#/components/schemas/" &
                                typeName
                            }
                          else:
                            %*{"type": typeName}
                  break # limit to single body only
              of "response":
                if not api["paths"][url][mtdNameLower].hasKey(
                  "responses"
                ):
                  api["paths"][url][mtdNameLower]["responses"] =
                    %*{}
                for respDef in v:
                  #[
                  Accepts the following:
                  - 200 (TypeName) "description"
                  - 200 "description, can also have spaces"
                  - 200 (TypeName)
                  - 200

                  TypeName should be something that is defined
                  in the @schema of the containing router.
                  ]#
                  var m = RegexMatch2()
                  let txt = respDef
                  var respCode = ""
                  if regex.match(
                    txt,
                    re2"""(?x)
                  ^
                    (?P<respCode>\d+)
                    (?:\s+
                      (?:
                        \( (?P<respType>\w+) \) |
                        (?P<respDescription1>".+?")
                      )
                    )?
                    (?:\s+
                      (?P<respDescription2>".+?")
                    )?
                  $""",
                    m,
                  ):
                    block addRespCode:
                      let i = m.group("respCode")
                      if i.a < 0:
                        break addRespCode
                      else:
                        respCode = txt[i]

                        api["paths"][url][mtdNameLower][
                          "responses"
                        ][respCode] = %*{}

                    block addRespType:
                      let i = m.group("respType")
                      if i.a < 0:
                        break addRespType
                      else:
                        let typeName = txt[i]
                        #[
                        Create schema out of Nim types... well, if I could
                        in the first place.
                        
                        Can't link to symbols outside this macro???  :(
                        ]#
                        when false:
                          if not api["components"]["schemas"].hasKey(
                            typeName
                          ):
                            api["components"]["schemas"][
                              typeName
                            ] =
                              %*{
                                "type": "object",
                                "properties": %*{},
                              }
                            let objSym =
                              bindSym(typeName, brForceOpen)
                            let objImpl = objSym.getImpl()
                            let objFields = objImpl[2][2]
                            for identDef in objFields:
                              let name = identDef[0].strVal()
                              let propType = identDef[1]
                              let jsonSafePropType =
                                propType.strVal()

                              api["components"]["schemas"][
                                typeName
                              ]["properties"][name] =
                                %*{
                                  "type": jsonSafePropType.newJString()
                                }

                        # Then link to the schema in the response definition
                        let respSchema =
                          if typeName in schemaDefs:
                            %*{
                              "$ref":
                                "#/components/schemas/" &
                                typeName
                            }
                          else:
                            %*{"type": typeName}

                        api["paths"][url][mtdNameLower][
                          "responses"
                        ][respCode]["content"] =
                          %*{
                            produceType: {"schema": respSchema}
                          }

                    block addRespDesc:
                      let i = block:
                        let i = m.group("respDescription1")
                        if i.a < 0:
                          m.group("respDescription2")
                        else:
                          i
                      let finalRespDesc = if i.a < 0:
                          ($HttpCode(parseInt(respCode))).newJString()
                        else:
                          txt[i.a + 1 .. i.b - 1].newJString()

                      api["paths"][url][mtdNameLower]["responses"][respCode]["description"] = finalRespDesc
                          
              else:
                api["paths"][url][mtdNameLower][k] =
                  v[0].newJString()
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
    of nnkCommentStmt:
      when defined(routerGenerateSwagger):
        let parsedDocResult =
          node.strVal.parseSwaggerDocComment()
        if parsedDocResult.isSome():
          let parsedDoc = parsedDocResult.get()
          for k, v in pairs(parsedDoc):
            case k
            of "server":
              #[
              Accepts:
                - @url http://127.0.0.1 Test server
                - @url http://127.0.0.1
              ]#
              for serverDef in v:
                let n = serverDef.split(' ', maxsplit = 1)
                case len(n)
                of 1:
                  api["servers"].add(%*{"url": n[0]})
                of 2:
                  api["servers"].add(
                    %*{"url": n[0], "description": n[1]}
                  )
                else:
                  discard
            of "security":
              for securityDef in v:
                let n = securityDef.split(' ', maxsplit = 1)
                let securityDefName = n[0]
                let securityDefContent = n[1].parseJson()

                api["components"]["securitySchemes"][
                  securityDefName
                ] = securityDefContent
            of "schema":
              for schemaDef in v:
                let n = schemaDef.split(' ', maxsplit = 1)
                let typeName = n[0]
                let typeContent = n[1].parseJson()
                api["components"]["schemas"][typeName] =
                  typeContent
                schemaDefs.add(typeName)
            else:
              api["info"][k] = v[0].newJString()
      else:
        discard
    else:
      discard

  when defined(routerGenerateSwagger):
    when defined(routerGenerateSwaggerStdout):
      debugEcho api.pretty()
    else:
      # Output generated OpenAPI spec to a file
      writeFile("router_" & name.strval & ".json", api.pretty())

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
