//go:generate protoc -I cpi --go_out=plugins=grpc:cpi cpi/cpi.proto

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os/exec"

	pb "github.com/cloudfoundry/bosh-cpi/cpi"
	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	addr    = flag.String("addr", "/tmp/cpi.socket", "unix socket / tcp addr to serve at")
	network = flag.String("net", "unix", "listen type (tcp/unix)")
)

// server is used to implement helloworld.GreeterServer.
type server struct{}

type CPIError struct {
	Type      string `json:"type"`
	Message   string `json:"message"`
	OkToRetry bool   `json:"ok_to_retry"`
}

type CPIResponse struct {
	Log   string    `json:"request_id"`
	Error *CPIError `json:"error"`

	Result interface{} `json:"result"`
}

func cpi(method string, in *pb.Request) (*pb.Response, []byte, error) {
	requestID, err := generateRequestID()
	if err != nil {
		log.Println("failed to generate unique requestd id", err)
		return nil, nil, err
	}

	context := map[string]interface{}{
		"director_uuid": in.DirectorUuid,
		"request_id":    requestID,
	}

	if in.StemcellApiVersion != 0 {
		context["vm"] = map[string]interface{}{
			"stemcell": map[string]interface{}{
				"api_version": in.StemcellApiVersion,
			},
		}
	}

	cmd := exec.Command(in.Type)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		log.Println("failed to setup cpi command stdin pipe", err)
		return nil, nil, err
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Println("failed to setup cpi command stdout pipe", err)
		return nil, nil, err
	}
	defer stdout.Close()

	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Println("failed to setup cpi command stderr pipe", err)
		return nil, nil, err
	}
	defer stderr.Close()

	cmd.Start()

	input := ExecRequest{Method: method, Context: context}
	encoder := json.NewEncoder(stdin)
	encoder.Encode(input)
	stdin.Close()

	decoder := json.NewDecoder(stdout)
	cpiResponse := CPIResponse{}
	err = decoder.Decode(&cpiResponse)
	if err != nil {
		log.Println("failed to read cpi response", err)
		return nil, nil, err
	}

	stderrContents, err := ioutil.ReadAll(stderr)
	if err != nil {
		log.Println("failed to read stderr", err)
	}

	err = cmd.Wait()
	if err != nil {
		log.Println("failed to run cpi command", err)
		return nil, nil, err
	}

	response := &pb.Response{Log: cpiResponse.Log}
	response.Log += string(stderrContents)

	if cpiResponse.Error != nil {
		e := cpiResponse.Error
		response.Error = &pb.Response_Error{
			Type:      e.Type,
			Message:   e.Message,
			OkToRetry: e.OkToRetry,
		}
	}

	resultBytes, err := json.Marshal(cpiResponse.Result)
	if err != nil {
		log.Println("failed to marshal result bytes", err)
		return nil, nil, err
	}

	return response, resultBytes, nil
}

type ExecRequest struct {
	Method string `json:"method"`
	// arguments []string `json:"arguments"`
	Context    map[string]interface{} `json:"context"`
	APIVersion int                    `json:"api_version,omitempty"`
}

func generateRequestID() (string, error) {
	guid, err := uuid.NewUUID()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("cpi-%s", guid), nil
}

func (s *server) Info(ctx context.Context, in *pb.Request) (*pb.Response, error) {
	response, resultBytes, err := cpi("info", in)
	if err != nil {
		return nil, err
	}

	infoResponse := &pb.InfoResult{}
	err = json.Unmarshal(resultBytes, infoResponse)
	if err != nil {
		return nil, err
	}
	response.Result = &pb.Response_InfoResult{InfoResult: infoResponse}

	return response, nil
}

func main() {
	flag.Parse()
	log.Println("Starting")

	lis, err := net.Listen(*network, *addr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterCPIServer(s, &server{})

	reflection.Register(s)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
