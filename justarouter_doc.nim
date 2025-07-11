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

```
@produces <MIME type>
```
- Maps to `.paths.*.*.content.<MIME type>`.
- It's named after the `produces` section of Swagger 2.x.

```
@response <HTTP code>
@response <HTTP code> "<Description>"
@response <HTTP code> (<Schema>)
@response <HTTP code> (<Schema>) "<Description>"
```
- Maps to `.paths.*.*.responses`.
- Multiple of these can be specified, in any form.
- HTTP code and schema may NOT have spaces.
- Schema MUST be something that is defined as a `@schema` in the General API information.

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

See section "Generating OpenAPI specs".

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
