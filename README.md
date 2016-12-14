## To Run

```
elm-live main.elm --debug
```

## Possible Plans
Server Info:
- Name
- IP
- If it is stashed
  + Reason
  + When was it stashed
  + How much longer is it stashed for
  + Who stashed it
- Stashed alerts
- Healthcheck
- Version
- Config
- If it is in the lb
- If it is different than the majority of servers (version/healthcheck/config)
- Maybe link to grafana/splunk dashboards

Actions
- Remove from the lb
- Stash all alerts
- Stash specified alerts
- Chef (Deploy=1)

