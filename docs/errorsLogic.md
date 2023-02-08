# How manage error on Lenra

### Error Level

- emergency: when the system cannot be used (ex : openfass_not_reachable after 5 attempts)  
- alert: something got wrong and need our attention, (ex: openfass_not_reachable less than 5 - times, mongo_connection, ecto connection error, ...)  
- critical: when the error can make system crash (ex: view genserver crash/ query genserver crash), basicly we can found this error in try/catch  
- error: normal error  
- warning: something goes wrong but it not impact workflow  
- notice: hightlight a message  
- info: info message (ex: socket started, channel_started)  
- debug: debug message  

All error will be notice with `Logger` and send to Sentry.

### Genserver

We need to focus on Genserver stability, see genserver [docs](docs/errorsLogic.md) for more info.

Some rules:
- Add default function for all pattern match, raise warning/error/critical following the case
- In our business logic we need some times to also send message to the websocket, notify the user something appenes
- All Genserver call need to be put in try/rescue, for now we just log an error and notify users to reload the app, in the future we can see for try restart genserver

### Alert/Emergency error  
  
Alert message are sent when the problems need our attention, some exemple:
- Openfaas not recheable/timeout
- Postgres/Mongo not recheable
- Function not fund in Openfaas, this can normally NEVER appens in our workflow
- (In the same idea), mongo_user_idea not found normally created on first launch of environment if we cannot found it later this is an alert, this should NEVER appens in normal ways

Use telemtry event for sned alert, after 5 alert telemetry send emergency