package server_test

import (
	"context"

	pb "github.com/cloudfoundry/bosh-cpi/cpi"
	"github.com/cloudfoundry/bosh-cpi/protostruct"
	"github.com/cloudfoundry/bosh-cpi/server"
	"github.com/cloudfoundry/bosh-cpi/server/serverfakes"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Server", func() {
	var (
		s pb.CPIServer

		fakeExecutor *serverfakes.FakeCPIExecutor
	)

	BeforeEach(func() {
		fakeExecutor = new(serverfakes.FakeCPIExecutor)
		s = server.New(fakeExecutor)
	})

	Describe("Info", func() {
		It("returns the API version and the stemcell formats", func() {
			fakeExecutor.ExecuteReturns(&server.CPIResponse{
				Result: map[string]interface{}{
					"api_version":      37,
					"stemcell_formats": []string{"format-1", "format-2"},
				},
			}, nil)

			request := &pb.Request{}
			response, err := s.Info(context.Background(), request)
			Expect(err).NotTo(HaveOccurred())

			Expect(response.RequestId).To(MatchRegexp("^cpi-[a-z0-9-]+$"))
			Expect(response.Error).To(BeNil())

			result := response.GetInfoResult()
			Expect(result.ApiVersion).To(BeNumerically("==", 37))
			Expect(result.StemcellFormats).To(ConsistOf("format-1", "format-2"))
		})

		It("passed down properties to the cpi executor", func() {
			fakeExecutor.ExecuteReturns(&server.CPIResponse{}, nil)
			properties := protostruct.FromMap(map[string]interface{}{
				"my_property": "my-value",
			})

			request := &pb.Request{Properties: properties}

			_, err := s.Info(context.Background(), request)
			Expect(err).NotTo(HaveOccurred())

			Expect(fakeExecutor.ExecuteCallCount()).To(Equal(1))
			_, cpiRequest := fakeExecutor.ExecuteArgsForCall(0)

			Expect(cpiRequest.Context["my_property"]).To(Equal("my-value"))
		})
	})

	Describe("CreateVM", func() {
		var (
			request *pb.Request
		)

		BeforeEach(func() {
			request = &pb.Request{
				Arguments: &pb.Request_CreateVmArguments{
					CreateVmArguments: &pb.CreateVMArguments{
						AgentId:    "agent-id",
						StemcellId: "stemcell-id",
						CloudProperties: protostruct.FromMap(map[string]interface{}{
							"blah": "cloud properties",
						}),
						Networks: protostruct.FromMap(map[string]interface{}{
							"blah": "networks",
						}),
						DiskCids: []string{"disk1", "disk2"},
						Env: protostruct.FromMap(map[string]interface{}{
							"blah": "env",
						}),
					},
				},
			}
		})

		It("executes the CPI with appropriate arguments", func() {
			fakeExecutor.ExecuteReturns(&server.CPIResponse{
				Result: "vm-cid",
			}, nil)

			_, err := s.CreateVM(context.Background(), request)
			Expect(err).ToNot(HaveOccurred())

			Expect(fakeExecutor.ExecuteCallCount()).To(Equal(1))
			_, cpiRequest := fakeExecutor.ExecuteArgsForCall(0)
			Expect(cpiRequest.Arguments).To(Equal(
				[]interface{}{
					"agent-id",
					"stemcell-id",
					map[string]interface{}{
						"blah": "cloud properties",
					},
					map[string]interface{}{
						"blah": "networks",
					},
					[]string{"disk1", "disk2"},
					map[string]interface{}{
						"blah": "env",
					},
				},
			))
		})

		Context("v1", func() {
			It("returns the vm cid", func() {
				fakeExecutor.ExecuteReturns(&server.CPIResponse{
					Result: "super-cool-vm-cid",
				}, nil)

				response, err := s.CreateVM(context.Background(), request)
				Expect(err).NotTo(HaveOccurred())

				Expect(response.RequestId).To(MatchRegexp("^cpi-[a-z0-9-]+$"))
				Expect(response.Error).To(BeNil())

				result := response.GetCreateVmResult()
				Expect(result.VmCid).To(Equal("super-cool-vm-cid"))
			})
		})
	})
})
