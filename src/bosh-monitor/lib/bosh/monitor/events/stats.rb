module Bosh::Monitor
  module Events
    class Stats < Base

      attr_reader :kind

      def initialize(attributes = {})
        super
        @kind = :stats

        @id = @attributes['id']
        @cpu = @attributes['cpu']
        @memory = @attributes['memory']
        @disk = @attributes['disk']

        # This rescue is just to preserve existing test behavior. However, this
        # seems like a pretty wacky way to handle errors - wouldn't we rather
        # have a nice exception?
        @created_at = Time.at(@attributes['created_at']) rescue @attributes['created_at']
      end

      def validate
        add_error('id is missing') if @id.nil?
        add_error('cpu is missing') if @cpu.nil?
        add_error('disk is missing') if @disk.nil?
        add_error('memory is missing') if @memory.nil?

        add_error('timestamp is missing') if @created_at.nil?

        if @created_at && !@created_at.kind_of?(Time)
          add_error('created_at is invalid UNIX timestamp')
        end
      end

      def to_hash
        {
          :kind        => @kind.to_s,
          :id          => @id,
          :cpu         => @cpu,
          :disk        => @disk,
          :memory      => @memory,
          :created_at  => @created_at.to_i
        }
      end

      def to_json
        JSON.dump(self.to_hash)
      end

      def to_s
        "Stats @ #{@created_at.utc}"
      end
    end
  end
end
