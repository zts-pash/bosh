module Bosh::Director::Metrics::Prometheus::Filter
  class Name
    def initialize(name)
      @key = name
    end

    def can_apply?(metric_family)
      metric_family.name == @key
    end
  end

  class Label
    def initialize(label_name, label_value)
      @label_name = label_name
      @label_value = label_value
    end

    def can_apply?(metric_family)
      return false if metric_family.metric.nil?

      metric_family.metric.each do |metric|
        metric.label.to_a.each do |label|
          return true if label.name == @label_name && label.value == @label_value
        end
      end
      false
    end
  end

  class And
    def initialize(filter1, *more_filters)
      @filters = [filter1, more_filters.to_a].flatten
    end

    def can_apply?(metric_family)
      @filters.each do |filter|
        return false unless filter.can_apply?(metric_family)
      end
      true
    end
  end

  class Or
    def initialize(filter1, *more_filters)
      @filters = [filter1, more_filters.to_a].flatten
    end

    def can_apply?(metric_family)
      @filters.each do |filter|
        return true if filter.can_apply?(metric_family)
      end
      false
    end
  end
end
