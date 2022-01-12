# The Environment and Session achitecture

## How does it work ?

There is two major actor involved in the process of running an app for a user.
- An Environment is a specific version of an app. The Environment handles everything that is in common between every users of a specific version of the application (The cache of all widget for example.)
- A session is a device opened in a specific App. The session is linked to the Environment and handles all IN/OUT between the client socket and the Environment. The session handle everyhting that is specific to a user (the state of the UI for example.)

To modelize these two actor and everything they handle in the Erlang VM, we use GenServer, DynamicSupervisor and Supervisor.
- An environment is materialized with a `EnvManager`
- All environments are supervised by a DynamicSupervisor `EnvManagers`
- An `EnvManager` need submodules to handle different features. These modules are handled by `EnvSupervisor`
And for the sessions :
- A session is materialized with a `SessionManager` GenServer.
- All sessions are supervised by a DynamicSupervisor `SessionManagers`
- A `SessionManager` needs submodules to handle different features (cache for example). These modules are handled by the `SessionSupervisor`

All the `SessionManager` and `EnvManager` are registered by a distributed registry : `Swarm`. This ensures that every Session and every Environment are only created once across all nodes of the cluster.

![Env and Session Tree](diagrams/EnvSessionTree.svg)


## A few design notes :
- The `EnvManager` has an `EnvState` internal state
- The `SessionManager` has a `SessionState` internal state
- The `SessionManager` handles every In/Out external API.
- We should NOT directly call the `EnvManager`.
- The `SessionManager`s are linked to the `EnvManager`s
- If the `EnvManager` is stopped, all the `SessionManager` are stopped too.
- The `SessionManager` is stopped after 10 min of inactivity (see config file.)
- The `EnvManager` is stopped after 60 min of inactivity (see config file.)

## Sequence diagram from the client call to the UI response.
![Sequence Diagram](diagrams/SequenceWidget.svg)