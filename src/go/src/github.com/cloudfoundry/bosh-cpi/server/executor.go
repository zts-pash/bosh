package server

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os/exec"
)

type CommandRunner struct{}

func (*CommandRunner) Execute(path string, request CPIRequest) (*CPIResponse, error) {
	cmd := exec.Command(path)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Println("failed to setup cpi command stdin pipe", err)
		return nil, err
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Println("failed to setup cpi command stdout pipe", err)
		return nil, err
	}
	defer stdout.Close()

	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Println("failed to setup cpi command stderr pipe", err)
		return nil, err
	}
	defer stderr.Close()

	cmd.Start()

	encoder := json.NewEncoder(stdin)
	encoder.Encode(request)
	stdin.Close()

	decoder := json.NewDecoder(stdout)
	cpiResponse := &CPIResponse{}
	err = decoder.Decode(cpiResponse)
	if err != nil {
		log.Println("failed to read cpi response", err)
		return nil, err
	}

	stderrContents, err := ioutil.ReadAll(stderr)
	if err != nil {
		log.Println("failed to read stderr", err)
	}

	err = cmd.Wait()
	if err != nil {
		log.Println("failed to run cpi command", err)
		return nil, err
	}
	cpiResponse.Log += string(stderrContents)

	return cpiResponse, nil
}
