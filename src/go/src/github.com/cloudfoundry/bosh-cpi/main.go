//go:generate protoc -I cpi --go_out=plugins=grpc:cpi cpi/cpi.proto

package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net"
	"os/exec"

	pb "github.com/cloudfoundry/bosh-cpi/cpi"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	addr    = flag.String("addr", "/tmp/cpi.socket", "unix socket / tcp addr to serve at")
	network = flag.String("net", "unix", "listen type (tcp/unix)")
)

// server is used to implement helloworld.GreeterServer.
type server struct{}

func cpi(path string, input Request) (*pb.BaseResponse, map[string]interface{}, error) {
	cmd := exec.Command(path)
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

	cmd.Start()

	encoder := json.NewEncoder(stdin)
	encoder.Encode(input)
	stdin.Close()

	decoder := json.NewDecoder(stdout)
	response := map[string]interface{}{}
	err = decoder.Decode(&response)
	if err != nil {
		log.Println("failed to decode cpi response", err)
		return nil, nil, err
	}

	err = cmd.Wait()
	if err != nil {
		log.Println("failed to run cpi command", err)
		return nil, nil, err
	}

	log.Printf("FROM CPI: %+v\n", response)

	base := &pb.BaseResponse{}
	if log, ok := response["log"]; ok {
		base.Log, _ = log.(string)
	}
	if e, ok := response["error"]; ok {
		base.Error, _ = e.(string)
	}
	var result map[string]interface{}
	if r, ok := response["result"]; ok {
		result, _ = r.(map[string]interface{})
	}

	return base, result, nil
}

// def request_json(method_name, arguments, context)
//   request_hash = {
//     'method' => method_name,
//     'arguments' => arguments,
//     'context' => context,
//   }

//   request_hash['api_version'] = request_cpi_api_version unless request_cpi_api_version.nil?
//   JSON.dump(request_hash)
// end

type Request struct {
	Method string `json:"method"`
	// arguments []string `json:"arguments"`
	Context    map[string]interface{} `json:"context"`
	APIVersion int                    `json:"api_version,omitempty"`
}

func (s *server) Info(ctx context.Context, in *pb.BaseRequest) (*pb.InfoResponse, error) {

	log.Printf("Received: %+v", in)
	requestID := "cpi-12345"

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

	base, result, err := cpi(in.Type, Request{Method: "info", Context: context})
	if err != nil {
		return nil, err
	}
	log.Println("result:", result)

	response := &pb.InfoResponse{Base: base}
	if v, ok := result["stemcell_formats"]; ok {
		if stemcellFormats, ok := v.([]interface{}); ok {
			for _, f := range stemcellFormats {
				response.StemcellFormats = append(response.StemcellFormats, f.(string))
			}
		}
	}
	if v, ok := result["api_version"]; ok {
		response.ApiVersion = int32(v.(float64))
	}

	log.Printf("RESPONDING WITH: %+v\n", response)

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
	// Register reflection service on gRPC server.
	reflection.Register(s)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
