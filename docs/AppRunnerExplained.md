# How does ApplicationRunner works ?


## General tree organisation
### The Environment Tree
The Blue part is the environment tree. It exists only once per environment.
An environment is a specific instance of an app with its own data.
Multiple environments can be created for one app. They behave like two app with two databases.

If the environment stop (if unused enought time) it is restarted when a session is asked to be oppened first.

TODO : Explain the full blue tree

### The Session Tree
The red part is the Session Tree. It exists once per user session and lives in an environment
One user can open multiple sessions. 
A session is defined by a unique ID (UUID).

A session can be stopped after a long inactivity time.
If it's the case, the client will open a new session (new socket connexion)

TODO : Explain the full red tree

### The Route tree
The yellow part is the Route Tree. It exists once per route and lives in a session.
A route is basically a UI/JSON that lives under a URI.
For example, the route **/users/42** could display a specific user information (for the Lenra UI) or return a specific JSON (for the JSON routes)

![Env and Session Tree](diagrams/app_runner_schema.drawio.svg)

## Start the app
### Socket initialization (simplified)

When the socket is initialized (when the user join the app), we also start the Session (Red tree) and the Environment (Blue tree) if it is not started.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Client
    participant AppSocket
    participant Environment
    participant Session
    User->>+Client: Open app
    Client->>+AppSocket: Open the socket
    Note over AppSocket: Check permission
    opt Environment not started
        AppSocket->>+Environment: Start the Environment and deps (blue tree)
        Note over Environment: OnEnvStart is triggered now
    end
    AppSocket->>+Session: Start the Session and deps (Red tree)
    Note over Environment: OnUserFirstJoin is triggered now only the first time the user enter the app
    Note over Environment: OnSessionStart is triggered now
    AppSocket-->>Client: Ok, accepted
    deactivate AppSocket
    deactivate Session
    deactivate Environment
    deactivate Client
```

### New Route Channel (simplified)

When the client open a new route, we start the corresponding RouteSupervisor (Yellow tree)
It directly trigger a UI push in this route channel.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Client
    participant RouteChannel
    participant RouteSupervisor
    participant RouteServer
    participant WidgetServer
    participant QueryServer
    participant App
    participant Mongo
    activate Client
    activate Mongo
    activate App
    Client->>+RouteChannel: join route
    RouteChannel->>+RouteSupervisor: Start the Route supervisor (Yellow tree)
    RouteSupervisor->>+RouteServer: Start Route
    alt Lenra Route
        Note over RouteServer: RouteServer use LenraBuilder
        loop recursively
            RouteServer->>+WidgetServer: start(query, name, props)
            WidgetServer->>+QueryServer: start(query)
            QueryServer->>Mongo: getData(query)
            Mongo-->>QueryServer: Data
            WidgetServer->>QueryServer: getData
            QueryServer-->>WidgetServer: data
            RouteServer->>WidgetServer: getWidget
            WidgetServer-->>RouteServer: widget
        end
    else Json Route
        Note over RouteServer: RouteServer use JsonBuilder
        RouteServer->>+WidgetServer: start(query, name, props)
        WidgetServer->>+QueryServer: start(query)
        QueryServer->>Mongo: getData(query)
        Mongo-->>QueryServer: Data
        WidgetServer->>QueryServer: getData
        QueryServer-->>WidgetServer: data
        RouteServer->>WidgetServer: getWidget
        WidgetServer-->>RouteServer: widget
    end
    RouteChannel-->>Client: Ok
    RouteServer-->>Client: UI
    Client-->>User: Print UI

    deactivate Client
    deactivate Mongo
    deactivate App
    deactivate RouteChannel
    deactivate RouteSupervisor
    deactivate RouteServer
    deactivate WidgetServer
    deactivate QueryServer
```

## App lifecycle

### When a listener is called (simplified)

When the user interact with the UI, listeners can be sent to the Server.
When a listener is sent, the server will call the App listener to let the app interact with the data.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Client
    participant RouteChannel
    participant Session.EventHandler
    participant App
    participant DataApi
    participant Mongo
    activate Client
    activate RouteChannel
    activate Session.EventHandler
    activate App
    activate DataApi
    activate Mongo

    User->>Client: Trigger Listener (press button)
    Client->>RouteChannel: send listener with code
    RouteChannel->>Session.EventHandler: send_client_event(code)
    Session.EventHandler-->>Session.EventHandler: Translate code to action/props
    Session.EventHandler->>App: Http call listener (actio, props)
    opt if listener call data api
        loop Any number of call
            App->>DataApi: HttpCall for any CRUD operation
            DataApi->>Mongo: any CRUD operation on data
            Mongo-->>DataApi: OK
            DataApi-->>App: OK
        end
    end
    App-->>Session.EventHandler: OK
    Session.EventHandler-->>RouteChannel: OK
    RouteChannel-->>Client: OK

    deactivate Client
    deactivate RouteChannel
    deactivate Session.EventHandler
    deactivate App
    deactivate DataApi
    deactivate Mongo
```

### When a data change in mongo (simplified)

Generally during a listener call, the mongo data will change.
When this happen, the UI automatically updates.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Client
    participant RouteChannel
    participant RouteServer
    participant App
    participant WidgetServers
    participant QueryServers
    participant ChangeEventManagers
    participant ChangeStream
    participant Mongo

    activate Client
    activate Mongo
    activate ChangeStream
    activate ChangeEventManagers
    activate QueryServers
    activate WidgetServers
    activate RouteServer
    activate RouteChannel
    activate App

    Note over Mongo: A data changed in mongo
    Mongo->>ChangeStream: new change event
    ChangeStream->>ChangeEventManagers: Broadcast the event to all managers
    ChangeEventManagers->>QueryServers: Broadcast the event to all QueryServers
    opt Event match the query and not already handled
        QueryServers-->>QueryServers: Update the data
        QueryServers->>WidgetServers: data_changed(data)
        WidgetServers->>App: get widget
        App-->>WidgetServers: widget
    end
    QueryServers-->>ChangeEventManagers: OK
    Note over ChangeEventManagers: when all QueryServers are OK
    ChangeEventManagers->>RouteServer: update
    loop Recursively
        RouteServer->>WidgetServers: get widget
        WidgetServers-->>RouteServer: widget
    end
    RouteServer-->>RouteServer: Diff old/new ui
    RouteServer-->>RouteChannel: Patch UI
    RouteChannel-->>Client: PatchUi
    Client-->>User: New UI

    deactivate Client
    deactivate Mongo
    deactivate ChangeStream
    deactivate ChangeEventManagers
    deactivate QueryServers
    deactivate WidgetServers
    deactivate RouteServer
    deactivate RouteChannel
    deactivate App
```