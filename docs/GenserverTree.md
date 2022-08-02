## Applicationrunner Genserver tree

This doc regroupe documentation about all Genserver present in ApplicationRunner for Environmnent/Session/MongoDB

```mermaid
flowchart
Supervisor --> Environment.Managers
Environment.Managers --> Environment.Supervisor
Environment.Managers --> E.S...
Environment.Supervisor ---> Environment.Agent.Token
Environment.Supervisor --> Environment.EventHandler
Environment.Supervisor --> MTDS
Environment.Supervisor --> QDS
Environment.Supervisor --> Repo
Environment.Supervisor --> MSDS
Environment.Supervisor --> WDS
Environment.Supervisor --> ManifestHandler
Environment.Supervisor --> Event.OnEnvStart
Environment.Supervisor --> Session.Managers
Environment.Supervisor --> CS
Session.Managers --> Session.Supervisor
Session.Managers --> S.S...
Session.Supervisor --> Session.EventHandler
Session.Supervisor --> UIBuilder
Session.Supervisor --> Event.OnUserFirstJoin
Session.Supervisor --> Event.OnSessionStart
Session.Supervisor --> Session.Agent.Token
Session.Supervisor --> SCM
WDS --> W
MSDS --> MS
QDS --> Q
MTDS --> MT

```

with:

- **Supervisor**: the Applicationrunner supervisor
- **Environment.Managers**: The Environments dynamic supervisor
- **Environment.Supervisor**: The Environment supervisor that start env and all needed genserver
- **Session.Managers**: The Sessions dynamic supervisor
- **Session.Supervisor**: The Session supervisor that start session and all needed genserver
- QDS: **Query dynamic supervisor**, which starts Q, Q will be placed in the swarm group by the session.
- CS: **Change Stream**  
    - Started by Environment.Supervisor
    - Stopped by Environment.Supervisor
    - Notify `{:scm, env_id}`
    - timeout after X min
    - Jobs: 
        - Notify session change manager on mongo event
- SCM: **Session Change Manager**
    - In swarm group `{:scm, env_id}` 
    - Delete swarm group
    - Call all `{:q, session}`
    - Jobs:
        - Listen for message in `{:scm, env_id}` and call all `{:q, session}`
        - After all Query respond notify UiBuilder to rebuild 
- Q: **Query**, which listens to the swarm messages sent by QSD and notifies W if the data has changed.
    - Started by Environment.Supervisor
    - Stopped by Environment.Supervisor
    - In group `{:q, session_id}`
    - Jobs: 
        - called by SCM with Mongo Event, check if change impact query
        - If change concern data notify Widget to rebuild
        - If not respond :ok to SCM
- **UiBuilder**: Genserver that cache last ui and build new ui with widget cache
    - Started by session.supervisor
    - Stopped by session.supervisor
    - Called from SCM
    - Jobs: 
        - On startup build first ui and send it to client
        - On changed event rebuild ui (start new widget if needed) send diff with cached ui
        - Saved the UI for next send
- WDS: **Widget dynamic supervisor**, starts the widget.
    - dynamically start widget, requested by UiBuilder
- W: **Widget**, cache the widget interface, and listen to Q to rebuild if necessary.
    - Started by UiBuilder
    - Stopped by UiBuilder
    - In group `{:w, session_id}`
    - Timeout after X min
    - Jobs:
        - On startup buid ui first time
        - Listene to Query event to rebuild
- **MongoRepo**: a repository conncted to one mongo database.
    - Each environment got her own database
    - We have One MongoRepo genserver started by Environment
- MSDS: **Mongo Session Dynamic Supervisor**, start the Mongo session
- MS: **Mongo Session**, a session is started for each listener and stops when the listeners end.
- MTDS : **Mongo transaction dynamic supervisor**
- MT: **Mongo Transaction**, started by a request from the application and linked to a mongo session. 



Typically the all system will function like that:

### Startup 

>When an User start an application the Session.Managers do:

- Ensure the Environment started
- Start a new Session.Manager
- Start a SessionTokenAgent that generate and save the session token

>Environment manager init:

- Get the App manifest (sync)
- Send onEnvStart event (async)

>Session manager init:

- Ensure environment manager initilized
- Check if user join app for first time & send OnUserFirstJoin event (async)
- Send onSessionStart event (async)
- Start a widget genserver for each widget from manifest, each Widget have for id a "key" props/context/query
- Create a swarm group for each unique query present in actual ui and assign Widget with the correspodinf query in the group
- Start a query genserver that listen for change stream event

### Listeners

> On session listeners

- Session start a new event with event handler
- Session start a Mango session
- The application can make transaction by api request
- The mango session valide or revert change
- Change stream receive event from mongo and notify Query
- Query see if change impact follow data and notify if necessary the swarm groupe with query id
- If widget receive message from Query, they rebuild ui
- When all Query finish here action, and receive end message from widget, they can notify 
