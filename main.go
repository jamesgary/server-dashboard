package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os/exec"
	"sync"

	"golang.org/x/net/websocket"
)

/*
TODO:
stream output back
pause/restart function
*/

type Message struct {
	Cmd           string   `json:cmd`
	Username      string   `json:username`
	Servers       []string `json:servers`
	SilenceAlerts []string `json:silence`
	Concurrency   int      `json:concurrency`
}

type Response struct {
	Server string `json:server`
	Status string `json:status`
	Output string `json:output`
}

func cmdHandler(ws *websocket.Conn) {
	var data Message
	var err error
	for {
		err = websocket.JSON.Receive(ws, &data)
		if err == io.EOF {
			continue
		} else if err != nil {
			log.Println("error", err)
		} else if data.Cmd == "deploy" {
			log.Println("received data", data)
			deployHandler(ws, data)
		} else {
			log.Println(data)
		}
	}
}

func deployHandler(ws *websocket.Conn, data Message) {
	log.Println("Starting Deploy!")

	// Limit the number of servers we deploy to at once
	serverC := make(chan string, data.Concurrency)
	var wg sync.WaitGroup
	go func(wg *sync.WaitGroup) {
		for server := range serverC {
			go func(server string) {
				defer func() {
					wg.Done()
				}()

				// Send status to websocket
				err := json.NewEncoder(ws).Encode(Response{
					Server: server,
					Status: "deploying"})
				if err != nil {
					log.Println("error encoding to websocket", err)
					ws.Write([]byte(fmt.Sprintf(`{"server":"%s","error":"%s"}`, server, err)))
				}

				out, err := deploy(data.Username, server, nil)
				if err != nil {
					log.Println("error deploying", err)
					return
				}

				// TODO: save out
				o, err := ioutil.ReadAll(out)
				if err != nil {
					log.Println("err", err)
				}
				out.Close()
				log.Printf("Out: %s\n", o)

				// Send status to websocket
				err = json.NewEncoder(ws).Encode(Response{
					Server: server,
					Output: string(o),
					Status: "done"})
				if err != nil {
					log.Println("error encoding to websocket", err)
					ws.Write([]byte(fmt.Sprintf(`{"server":"%s","error":"%s"}`, server, err)))
				}
			}(server)
		}
	}(&wg)

	for _, server := range data.Servers {
		wg.Add(1)
		serverC <- server
	}
	wg.Wait()

	ws.Write([]byte("done"))
}

// deploy runs sudo DEPLOY=1 chef-client on the server
// silencing the alerts before the deploy
// unsilencing after the deploy
// and returns the stdout
func deploy(username string, server string, silenceAlerts []string) (io.ReadCloser, error) {
	silence(username, server, silenceAlerts)
	defer unsilence(username, server, silenceAlerts)

	log.Println("deploying to", server)
	deployCmd := fmt.Sprintf(`ssh -q %s uptime`, server)
	cmd := exec.Command("sh", "-c", deployCmd)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}
	cmd.Start()

	return &MultiOut{io.MultiReader(stdout, stderr), []io.Closer{stdout, stderr}}, nil
}

type MultiOut struct {
	reader  io.Reader
	closers []io.Closer
}

func (mo *MultiOut) Read(b []byte) (int, error) {
	return mo.reader.Read(b)
}
func (mo *MultiOut) Close() error {
	// we want to attempt closing both
	var combinedErr error
	var err error
	for _, r := range mo.closers {
		err = r.Close()
		if err != nil {
			fmt.Errorf("%s, %s", combinedErr, err)
		}
	}
	return combinedErr

}

type Sensu struct {
	Path    string   `json:"path"`
	Expire  int      `json:"expire"`
	Content *Content `json:"content"`
}
type Content struct {
	Reason   string `json:"reason"`
	Username string `json:"username"`
}

// silence returns a string cmd to silence the given alerts
// TODO: return whether this was successful or not
//
// curl -s -H "Content-Type:text/json" \
// http://sensu-mdw1.sendgrid.net:4567/stashes
// -d '{"path":"silence/`hostname`/check_filter_proc",
//      "expire":300,
//      "content":{
//          "reason":"restarting filterd",
//          "username":"trothaus"
//      }}'
func silence(username string, server string, alerts []string) error {
	var expire = 60 * 5 // expire in 5 minutes
	log.Printf("silencing alerts for user (%s) server (%s) for %d seconds: %v", username, server, expire, alerts)
	for alert := range alerts {
		sendRequest(
			"http://sensu-mdw1.sendgrid.net:4567/stashes",
			Sensu{
				Path:   fmt.Sprintf("silence/%s/%s", server, alert),
				Expire: expire,
				Content: &Content{
					Reason:   "deploying",
					Username: username},
			})

	}
	return nil
}

func unsilence(username string, server string, alerts []string) error {
	log.Printf("unsilencing alerts for user (%s) server (%s): %v", username, server, alerts)
	var expire = 0 // remove alert
	for alert := range alerts {
		sendRequest(
			"http://sensu-mdw1.sendgrid.net:4567/stashes",
			Sensu{
				Path:   fmt.Sprintf("silence/%s/%s", server, alert),
				Expire: expire,
				Content: &Content{
					Reason:   "deploying",
					Username: username},
			})

	}
	return nil
}

// TODO: return response
func sendRequest(url string, body interface{}) {
	json, err := json.Marshal(body)
	if err != nil {
		log.Printf("Unable to marshal body for url %s: %s\n", url, err.Error())
	}
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(json))
	if err != nil {
		log.Printf("Unable to post to url %s: %s\n", url, err.Error())
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		log.Printf("Post return %d for url %s: \n", resp.StatusCode, url)
		return
	}
	io.Copy(ioutil.Discard, resp.Body)
}

func main() {
	var port = ":9090"
	http.Handle("/deploy", websocket.Handler(cmdHandler))
	http.Handle("/", http.FileServer(http.Dir(".")))
	log.Println("listening on", port)
	err := http.ListenAndServe(port, nil)
	if err != nil {
		panic("ListenAndServe: " + err.Error())
	}
	log.Println("err", err)
}
