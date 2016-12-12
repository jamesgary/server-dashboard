## Interface

*websocket endpoints*
- `$HOST:$PORT/cmd`

*Request*
```
{ cmd: "deploy"
, username: "trothaus"
, servers: ["filter1190p1mdw1.sendgrid.net", "filter1193p1mdw1.sendgrid.net"]
, silence: ["alert1", "alert2"]
, concurrency: 40
}
```

*Responses*
- Individual server response
```
{ "server": "filter1190p1mdw1.sendgrid.net"
, "status": "deploying"
, "output": ""
}
```

- Error server response
```
{ "server": "filter1190p1mdw1.sendgrid.net"
, "status": "error"
, "output": "error message"
}
```

- Deploy Compplete
```
{ "status": "done" }
```
