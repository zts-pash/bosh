//go:generate protoc -I cpi --go_out=plugins=grpc:cpi cpi/cpi.proto

package main

import (
	"flag"
	"log"
	"net"

	pb "github.com/cloudfoundry/bosh-cpi/cpi"
	"github.com/cloudfoundry/bosh-cpi/server"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	addr    = flag.String("addr", "/tmp/cpi.socket", "unix socket / tcp addr to serve at")
	network = flag.String("net", "unix", "listen type (tcp/unix)")
)

func main() {
	flag.Parse()
	log.Println("Starting")

	lis, err := net.Listen(*network, *addr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterCPIServer(s, server.New(&server.CommandRunner{}))

	reflection.Register(s)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
