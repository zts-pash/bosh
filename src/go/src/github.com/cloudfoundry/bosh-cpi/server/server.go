package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	pb "github.com/cloudfoundry/bosh-cpi/cpi"
	"github.com/cloudfoundry/bosh-cpi/protostruct"
	structpb "github.com/golang/protobuf/ptypes/struct"
	"github.com/google/uuid"
)

type server struct {
	executor CPIExecutor
}

type CPIError struct {
	Type      string `json:"type"`
	Message   string `json:"message"`
	OkToRetry bool   `json:"ok_to_retry"`
}

type CPIRequest struct {
	Method     string                 `json:"method"`
	Arguments  []interface{}          `json:"arguments"`
	Context    map[string]interface{} `json:"context"`
	APIVersion int                    `json:"api_version,omitempty"`
}

type CPIResponse struct {
	Log   string    `json:"request_id"`
	Error *CPIError `json:"error"`

	Result interface{} `json:"result"`
}

//go:generate counterfeiter . CPIExecutor

type CPIExecutor interface {
	Execute(path string, request CPIRequest) (*CPIResponse, error)
}

func generateRequestID() (string, error) {
	guid, err := uuid.NewUUID()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("cpi-%s", guid), nil
}

func buildContext(requestID, directorUUID string, stemcellAPIVersion int32, properties *structpb.Struct) map[string]interface{} {
	context := map[string]interface{}{
		"director_uuid": directorUUID,
		"request_id":    requestID,
	}

	if stemcellAPIVersion != 0 {
		context["vm"] = map[string]interface{}{
			"stemcell": map[string]interface{}{
				"api_version": stemcellAPIVersion,
			},
		}
	}

	for k, v := range protostruct.ToMap(properties) {
		context[k] = v
	}

	return context
}

func New(executor CPIExecutor) pb.CPIServer {
	return &server{executor: executor}
}

func (s *server) cpi(method string, in *pb.Request, arguments []interface{}) (*pb.Response, []byte, error) {
	requestID, err := generateRequestID()
	if err != nil {
		log.Println("failed to generate unique requestd id", err)
		return nil, nil, err
	}

	context := buildContext(requestID, in.DirectorUuid, in.StemcellApiVersion, in.Properties)
	input := CPIRequest{Method: method, Context: context, Arguments: arguments}
	cpiResponse, err := s.executor.Execute(in.Type, input)
	if err != nil {
		log.Println("failed to call cpi", err)
		return nil, nil, err
	}

	response := &pb.Response{
		Log:       cpiResponse.Log,
		RequestId: requestID,
	}

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

func (s *server) Info(ctx context.Context, in *pb.Request) (*pb.Response, error) {
	response, resultBytes, err := s.cpi("info", in, nil)
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

func (s *server) CreateVM(ctx context.Context, in *pb.Request) (*pb.Response, error) {
	createVMArgs := in.GetCreateVmArguments()
	arguments := []interface{}{
		createVMArgs.AgentId,
		createVMArgs.StemcellId,
		protostruct.ToMap(createVMArgs.CloudProperties),
		protostruct.ToMap(createVMArgs.Networks),
		createVMArgs.DiskCids,
		protostruct.ToMap(createVMArgs.Env),
	}

	response, resultBytes, err := s.cpi("create_vm", in, arguments)
	if err != nil {
		return nil, err
	}

	createVMResponse := &pb.CreateVMResult{}
	err = json.Unmarshal(resultBytes, &createVMResponse.VmCid)
	if err != nil {
		return nil, err
	}
	response.Result = &pb.Response_CreateVmResult{CreateVmResult: createVMResponse}

	return response, nil
}
