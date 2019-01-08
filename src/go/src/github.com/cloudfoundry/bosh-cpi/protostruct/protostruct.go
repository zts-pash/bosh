package protostruct

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/golang/protobuf/jsonpb"
	pb "github.com/golang/protobuf/ptypes/struct"
)

func ToMap(s *pb.Struct) map[string]interface{} {
	if s == nil {
		return nil
	}
	m := map[string]interface{}{}
	for k, v := range s.Fields {
		m[k] = decodeValue(v)
	}
	return m
}

func FromMap(m map[string]interface{}) *pb.Struct {
	s := &pb.Struct{}
	r, w := io.Pipe()
	defer r.Close()

	go func() {
		defer w.Close()

		encoder := json.NewEncoder(w)
		err := encoder.Encode(m)
		if err != nil {
			panic(fmt.Sprintf("protostruct: %v", err))
		}
	}()

	err := jsonpb.Unmarshal(r, s)
	if err != nil {
		panic(fmt.Sprintf("protostruct: %v", err))
	}

	return s
}

func decodeValue(v *pb.Value) interface{} {
	switch k := v.Kind.(type) {
	case *pb.Value_NullValue:
		return nil
	case *pb.Value_NumberValue:
		return k.NumberValue
	case *pb.Value_StringValue:
		return k.StringValue
	case *pb.Value_BoolValue:
		return k.BoolValue
	case *pb.Value_StructValue:
		return ToMap(k.StructValue)
	case *pb.Value_ListValue:
		s := make([]interface{}, len(k.ListValue.Values))
		for i, e := range k.ListValue.Values {
			s[i] = decodeValue(e)
		}
		return s
	default:
		panic("protostruct: unknown kind")
	}
}
